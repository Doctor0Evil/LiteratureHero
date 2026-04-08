-- src/gesp_debias_analyzer.lua
-- GESP debunking layer: ΔD (dimension distortion) and dD (doom/agency)
-- built on top of an existing hex-GESP tagging / stress model.
--
-- Design goals:
--  - Do NOT hard-code risk thresholds; keep everything config-driven.
--  - Compute claimed vs estimated stress, ΔD, and doom/agency dD.
--  - Return structured objects that downstream tools (UI, docs, ML) can use.
--  - Stay compatible with the existing hex GESP model (0xGESP tags, s_D ∈ [0,1]).

local Debias = {}

----------------------------------------------------------------------
-- 0. Dependencies and integration hooks
----------------------------------------------------------------------

-- Expect an external module that provides:
--   - analyze_text(text) -> { s = {G=..,E=..,S=..,P=..}, hex_tag = "0xGESP", features = {...} }
--   - This is the "claimed" stress view, derived from narrative content.
local HexModel = require("models.collapseriskmodel")  -- adjust path as needed

-- Expect an external "context estimator" that can provide estimated stress
-- for a given text + metadata (e.g., country, time window, indicators).
-- This is left abstract here; callers can inject a function.
-- Signature: estimate_stress(context) -> {G=..,E=..,S=..,P=..}
Debias.estimate_stress = function(context)
  -- Placeholder implementation: callers MUST override.
  -- Return neutral mid-stress if not configured to avoid crashes.
  return { G = 0.5, E = 0.5, S = 0.5, P = 0.5 }
end

----------------------------------------------------------------------
-- 1. Utility: clamp and safe division
----------------------------------------------------------------------

local function clamp01(x)
  if x ~= x then return 0 end       -- NaN guard
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function safediv(num, den, eps)
  eps = eps or 1e-6
  den = den or 0
  if den == 0 then den = eps end
  return num / den
end

----------------------------------------------------------------------
-- 2. Doom/Agency lexical layer (dimension-aware dD)
----------------------------------------------------------------------

-- Configurable lexicons; callers may override at runtime.
-- Doom/agency tokens can be interpreted dimension-specifically using heuristics.
Debias.lexicons = {
  doom = {
    "inevitable", "nothing-we-can-do", "too-late", "doomed",
    "collapse-is-certain", "point-of-no-return", "hopeless"
  },
  agency = {
    "organize", "adapt", "mitigate", "reform", "resilience",
    "solidarity", "mutual-aid", "policy", "cooperate", "mobilize"
  }
}

-- Optional dimension hints for simple dimension-aware doom/agency tagging.
-- This is intentionally minimal; callers can extend or replace.
Debias.dimension_hints = {
  G = { "climate", "sea-level", "flood", "heatwave", "drought", "storm" },
  E = { "jobs", "housing", "wages", "inflation", "recession", "debt" },
  S = { "community", "trust", "neighbors", "polarization", "riot", "protest" },
  P = { "government", "election", "courts", "constitution", "regime", "coup" }
}

local function tokenize(text)
  local tokens = {}
  if not text or text == "" then return tokens end
  for token in string.gmatch(string.lower(text), "%S+") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

local function build_lookup(list)
  local lookup = {}
  for _, w in ipairs(list or {}) do
    lookup[w] = true
  end
  return lookup
end

-- Count doom/agency tokens overall and by dimension (heuristic).
local function count_doom_agency(text)
  local tokens = tokenize(text)
  local doom_lut   = build_lookup(Debias.lexicons.doom)
  local agency_lut = build_lookup(Debias.lexicons.agency)

  local Dneg_total, Dpos_total = 0, 0
  local dim_counts = {
    G = { doom = 0, agency = 0 },
    E = { doom = 0, agency = 0 },
    S = { doom = 0, agency = 0 },
    P = { doom = 0, agency = 0 }
  }

  -- Pre-build dimension hint lookup.
  local dim_hint_luts = {}
  for dim, words in pairs(Debias.dimension_hints) do
    dim_hint_luts[dim] = build_lookup(words)
  end

  -- Simple heuristic:
  --  - If a token matches doom or agency, increment total.
  --  - If the *sentence* contains hint words for a dimension, attribute counts there too.
  -- For simplicity, treat whole text as one segment with hints.
  local hint_active = { G = false, E = false, S = false, P = false }
  for _, t in ipairs(tokens) do
    for dim, lut in pairs(dim_hint_luts) do
      if lut[t] then
        hint_active[dim] = true
      end
    end
  end

  for _, t in ipairs(tokens) do
    local is_doom = doom_lut[t] and true or false
    local is_ag   = agency_lut[t] and true or false
    if is_doom then
      Dneg_total = Dneg_total + 1
      for dim, active in pairs(hint_active) do
        if active then dim_counts[dim].doom = dim_counts[dim].doom + 1 end
      end
    elseif is_ag then
      Dpos_total = Dpos_total + 1
      for dim, active in pairs(hint_active) do
        if active then dim_counts[dim].agency = dim_counts[dim].agency + 1 end
      end
    end
  end

  return {
    total = { doom = Dneg_total, agency = Dpos_total },
    per_dim = dim_counts
  }
end

-- Compute overall dD and per-dimension dD.
local function compute_dD(doom_agency_counts)
  local Dneg_total = doom_agency_counts.total.doom or 0
  local Dpos_total = doom_agency_counts.total.agency or 0
  local overall = safediv(Dneg_total, Dneg_total + Dpos_total)

  local per_dim = {}
  for dim, counts in pairs(doom_agency_counts.per_dim) do
    local neg = counts.doom or 0
    local pos = counts.agency or 0
    per_dim[dim] = safediv(neg, neg + pos)
  end

  return overall, per_dim
end

-- Optional qualitative label for dD, using soft bands from config.
Debias.dD_bands = { low = 0.33, high = 0.66 }

local function label_dD(dD, bands)
  bands = bands or Debias.dD_bands
  if dD <= bands.low then
    return "agency-leaning"
  elseif dD >= bands.high then
    return "doom-leaning"
  else
    return "mixed"
  end
end

----------------------------------------------------------------------
-- 3. Distortion vector ΔD between claimed and estimated stress
----------------------------------------------------------------------

-- Given two stress vectors in [0,1], compute ΔD = s_claimed - s_estimated
local function compute_delta(stress_claimed, stress_estimated)
  local delta = {}
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local c = clamp01(stress_claimed[dim] or 0)
    local e = clamp01(stress_estimated[dim] or 0)
    delta[dim] = c - e
  end
  return delta
end

-- Optional helper: compute a simple “distortion magnitude” per dimension
-- and an overall L2 norm for ranking or visualization.
local function summarize_delta(delta)
  local mag = {}
  local sumsq = 0
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local d = delta[dim] or 0
    mag[dim] = math.abs(d)
    sumsq = sumsq + d * d
  end
  local l2 = math.sqrt(sumsq)
  return {
    per_dim = mag,
    l2 = l2
  }
end

----------------------------------------------------------------------
-- 4. High-level analysis: text + context -> ΔD, dD, and hex GESP
----------------------------------------------------------------------

--- Analyze a single text fragment with optional context.
-- @param text    string  raw text
-- @param context table   metadata used by estimate_stress (country, year, etc.)
-- @param opts    table   optional; may contain:
--                        - estimate_stress_fn(context) override
--                        - bands for dD labeling
-- @return table  result  with fields:
--                        - stress_claimed  {G,E,S,P}
--                        - stress_estimated {G,E,S,P}
--                        - delta            {G,E,S,P}
--                        - delta_summary    {per_dim, l2}
--                        - hex_tag          "0xGESP"
--                        - dD_overall       number
--                        - dD_per_dim       {G,E,S,P}
--                        - dD_label         "agency-leaning"|"mixed"|"doom-leaning"
--                        - doom_agency_counts {total, per_dim}
--                        - features         (from HexModel, if provided)
--                        - debug            optional extra info
function Debias.analyze_text(text, context, opts)
  opts = opts or {}
  context = context or {}

  -- 1. Use existing hex GESP model to get narrative/claimed stress.
  local hex_result = HexModel.analyze_text(text, opts.hex_opts or {})
  local s_claimed = hex_result.stress or hex_result.s or { G = 0, E = 0, S = 0, P = 0 }
  local hex_tag   = hex_result.hex_tag or "0x0000"

  -- 2. Obtain estimated stress from external context estimator.
  local est_fn = opts.estimate_stress_fn or Debias.estimate_stress
  local s_estimated = est_fn(context) or { G = 0.5, E = 0.5, S = 0.5, P = 0.5 }

  -- 3. Compute ΔD and summary.
  local delta = compute_delta(s_claimed, s_estimated)
  local delta_summary = summarize_delta(delta)

  -- 4. Compute doom/agency counts and dD metrics.
  local doom_agency_counts = count_doom_agency(text)
  local dD_overall, dD_per_dim = compute_dD(doom_agency_counts)
  local dD_label = label_dD(dD_overall, opts.dD_bands or Debias.dD_bands)

  -- 5. Assemble result.
  local result = {
    stress_claimed      = s_claimed,
    stress_estimated    = s_estimated,
    delta               = delta,
    delta_summary       = delta_summary,
    hex_tag             = hex_tag,
    dD_overall          = dD_overall,
    dD_per_dim          = dD_per_dim,
    dD_label            = dD_label,
    doom_agency_counts  = doom_agency_counts,
    features            = hex_result.features,
    debug               = {
      raw_hex_result = hex_result
    }
  }

  return result
end

----------------------------------------------------------------------
-- 5. Batch processing helpers for corpus integration
----------------------------------------------------------------------

--- Analyze a list of records from the GESP discourse corpus.
-- Each record is expected to contain at least:
--   - text
--   - context (optional; could carry country, year, source_type, etc.)
-- The function returns a new table of results keyed by original index.
function Debias.analyze_batch(records, opts)
  opts = opts or {}
  local out = {}
  for idx, rec in ipairs(records or {}) do
    local text = rec.text or ""
    local context = rec.context or rec  -- allow record itself as context
    out[idx] = Debias.analyze_text(text, context, opts)
  end
  return out
end

----------------------------------------------------------------------
-- 6. Qualitative explanation stubs (hook for UI / docs)
----------------------------------------------------------------------

-- Optional helper: generate a human-readable explanation of ΔD and dD
-- for use in debunking pipelines or UIs. This is deliberately simple;
-- callers can extend/replace with richer templates.
function Debias.explain(result)
  local lines = {}
  lines[#lines + 1] = "GESP debunking summary:"
  lines[#lines + 1] = string.format("  Hex tag (claimed narrative stress): %s", result.hex_tag or "n/a")
  lines[#lines + 1] = string.format("  dD overall (doom vs agency): %.2f (%s)",
    result.dD_overall or 0, result.dD_label or "unknown")

  lines[#lines + 1] = "  ΔD per dimension (claimed - estimated):"
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local d = result.delta[dim] or 0
    lines[#lines + 1] = string.format("    %s: %+0.2f", dim, d)
  end

  lines[#lines + 1] = string.format("  Overall distortion magnitude (L2): %.2f",
    result.delta_summary.l2 or 0)

  return table.concat(lines, "\n")
end

return Debias
