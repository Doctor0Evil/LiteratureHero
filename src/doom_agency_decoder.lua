-- src/doom_agency_decoder.lua
-- Doom/agency decoder and dD computation for LiteratureHero.
--
-- Responsibilities:
--   - Tokenization
--   - Doom and agency lexicons
--   - Dimension hints and heuristic attribution (G, E, S, P)
--   - Doom/agency counting overall and per dimension
--   - d, d_D formulas with configurable qualitative bands

local DoomAgency = {}

----------------------------------------------------------------------
-- 0. Config: lexicons, dimension hints, bands
----------------------------------------------------------------------

-- Core doom and agency lexicons (can be overridden at runtime).
DoomAgency.lexicons = {
  doom = {
    "doomed", "inevitable", "inevitably", "too late", "collapse is certain",
    "nothing we can do", "nothing we can", "hopeless", "beyond saving",
    "point of no return", "no way out", "everything is broken"
  },
  agency = {
    "organize", "organized", "adapt", "adapting", "mitigate", "mitigation",
    "reform", "reforms", "resilience", "resilient", "solidarity",
    "mutual aid", "mutual-aid", "policy", "policies", "cooperate",
    "cooperation", "mobilize", "mobilizing", "build", "rebuild"
  }
}

-- Dimension hints for heuristic attribution of doom/agency counts.
-- These are intentionally minimal; callers should extend for real use.
DoomAgency.dimension_hints = {
  G = { "climate", "sea-level", "sea level", "flood", "heatwave", "heat wave",
        "drought", "storm", "infrastructure", "grid", "blackout", "wildfire" },
  E = { "jobs", "job", "housing", "rent", "wages", "wage", "inflation",
        "recession", "debt", "unemployment", "poverty", "prices" },
  S = { "community", "communities", "neighbors", "neighbours", "trust",
        "polarization", "polarisation", "riot", "riots", "protest",
        "protests", "conflict", "violence" },
  P = { "government", "state", "election", "elections", "courts",
        "constitution", "regime", "coup", "parliament", "congress",
        "party", "parties" }
}

-- Default qualitative bands for labeling d and d_D.
-- These are soft and should be tuned from corpus quantiles.
DoomAgency.d_bands = {
  low  = 0.33,   -- below this: agency-leaning
  high = 0.66    -- above this: doom-leaning
}

----------------------------------------------------------------------
-- 1. Tokenization and helper functions
----------------------------------------------------------------------

local function to_lower(s)
  return string.lower(s or "")
end

local function tokenize(text)
  local tokens = {}
  text = to_lower(text or "")
  for token in string.gmatch(text, "%w+") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

local function build_lookup(list)
  local lut = {}
  for _, w in ipairs(list or {}) do
    lut[to_lower(w)] = true
  end
  return lut
end

local function safe_div(num, den, eps)
  eps = eps or 1e-6
  den = den or 0
  if den == 0 then
    den = eps
  end
  return num / den
end

----------------------------------------------------------------------
-- 2. Doom/agency counting with dimension attribution
----------------------------------------------------------------------

-- Build lookup tables for doom, agency, and dimension hints.
local doom_lut, agency_lut, dim_hint_luts

local function ensure_lookups()
  if not doom_lut then
    doom_lut   = build_lookup(DoomAgency.lexicons.doom)
    agency_lut = build_lookup(DoomAgency.lexicons.agency)
  end
  if not dim_hint_luts then
    dim_hint_luts = {}
    for dim, words in pairs(DoomAgency.dimension_hints) do
      dim_hint_luts[dim] = build_lookup(words)
    end
  end
end

-- Infer which dimensions are salient in a text via hint words.
local function infer_active_dimensions(tokens)
  local active = { G = false, E = false, S = false, P = false }
  for _, t in ipairs(tokens) do
    for dim, lut in pairs(dim_hint_luts) do
      if lut[t] then
        active[dim] = true
      end
    end
  end
  return active
end

-- Public API: count_doom_agency(text)
-- Returns:
--   {
--     total = { doom = N_doom, agency = N_agency },
--     per_dim = {
--       G = { doom = n_doom_G, agency = n_agency_G }, ...
--     }
--   }
function DoomAgency.count_doom_agency(text)
  ensure_lookups()

  local tokens = tokenize(text)
  local active = infer_active_dimensions(tokens)

  local total_doom, total_agency = 0, 0
  local per_dim = {
    G = { doom = 0, agency = 0 },
    E = { doom = 0, agency = 0 },
    S = { doom = 0, agency = 0 },
    P = { doom = 0, agency = 0 }
  }

  -- For simplicity, attribute each doom/agency token to all active dimensions.
  for _, t in ipairs(tokens) do
    local is_doom   = doom_lut[t]   or false
    local is_agency = agency_lut[t] or false

    if is_doom then
      total_doom = total_doom + 1
      for dim, on in pairs(active) do
        if on then
          per_dim[dim].doom = per_dim[dim].doom + 1
        end
      end
    elseif is_agency then
      total_agency = total_agency + 1
      for dim, on in pairs(active) do
        if on then
          per_dim[dim].agency = per_dim[dim].agency + 1
        end
      end
    end
  end

  return {
    total   = { doom = total_doom, agency = total_agency },
    per_dim = per_dim
  }
end

----------------------------------------------------------------------
-- 3. d and d_D computation plus qualitative labels
----------------------------------------------------------------------

-- Public API: compute_d(counts)
-- Input:
--   counts = result of count_doom_agency
-- Output:
--   d_overall  in [0,1]
--   d_per_dim  table { G = d_G, ... } in [0,1]
function DoomAgency.compute_d(counts)
  local total = counts.total or {}
  local per   = counts.per_dim or {}

  local n_doom   = total.doom   or 0
  local n_agency = total.agency or 0
  local d_overall = safe_div(n_doom, n_doom + n_agency)

  local d_per_dim = {}
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local c = per[dim] or {}
    local nd = c.doom   or 0
    local na = c.agency or 0
    d_per_dim[dim] = safe_div(nd, nd + na)
  end

  return d_overall, d_per_dim
end

-- Public API: label_d(d_value, bands)
-- Returns "agency-leaning", "mixed", or "doom-leaning".
function DoomAgency.label_d(d_value, bands)
  bands = bands or DoomAgency.d_bands
  if d_value <= (bands.low or 0.33) then
    return "agency-leaning"
  elseif d_value >= (bands.high or 0.66) then
    return "doom-leaning"
  else
    return "mixed"
  end
end

----------------------------------------------------------------------
-- 4. High-level convenience
----------------------------------------------------------------------

-- Public API: analyze(text, opts)
-- Returns:
--   {
--     counts     = { total = {...}, per_dim = {...} },
--     d_overall  = number,
--     d_per_dim  = { G, E, S, P },
--     label      = string ("agency-leaning" / "mixed" / "doom-leaning")
--   }
function DoomAgency.analyze(text, opts)
  opts = opts or {}
  if opts.lexicons then
    DoomAgency.lexicons = opts.lexicons
    doom_lut   = nil
    agency_lut = nil
  end
  if opts.dimension_hints then
    DoomAgency.dimension_hints = opts.dimension_hints
    dim_hint_luts = nil
  end
  if opts.d_bands then
    DoomAgency.d_bands = opts.d_bands
  end

  local counts = DoomAgency.count_doom_agency(text)
  local d_overall, d_per_dim = DoomAgency.compute_d(counts)
  local label = DoomAgency.label_d(d_overall, DoomAgency.d_bands)

  return {
    counts    = counts,
    d_overall = d_overall,
    d_per_dim = d_per_dim,
    label     = label
  }
end

return DoomAgency
