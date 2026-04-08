-- src/geps_discourse_analyzer.lua
-- Modular G/E/S/P + d_D analysis stack (threshold-free, repo-aligned)

local Analyzer = {}

----------------------------------------------------------------------
-- 1. Core data structures: stress, resilience, and risk aggregation
----------------------------------------------------------------------

-- stress vector s = (G, E, S, P), each in [0,1]
-- resilience vector r = (G_r, E_r, S_r, P_r), each in [0,1]

-- Default weights and alpha for non-linear aggregation R = Σ w_i s_i^α
Analyzer.default_weights = { G = 1.0, E = 1.0, S = 1.0, P = 1.0 }
Analyzer.default_alpha   = 2.0

-- Combine stress and resilience into an effective risk factor.
-- C = f(s, r) here implemented as C = Σ w_i s_i^α (1 - r_i)
function Analyzer.effective_risk(stress, resilience, weights, alpha)
  weights  = weights  or Analyzer.default_weights
  alpha    = alpha    or Analyzer.default_alpha
  resilience = resilience or { G = 0, E = 0, S = 0, P = 0 }

  local C = 0.0
  for dim, s_val in pairs(stress) do
    local w = weights[dim] or 1.0
    local r = resilience[dim] or 0.0
    if s_val < 0 then s_val = 0 end
    if s_val > 1 then s_val = 1 end
    if r < 0 then r = 0 end
    if r > 1 then r = 1 end
    C = C + w * (s_val ^ alpha) * (1.0 - r)
  end
  return C
end

----------------------------------------------------------------------
-- 2. Tokenization and lexical feature extraction
----------------------------------------------------------------------

function Analyzer.tokenize(text)
  local tokens = {}
  for token in string.gmatch(string.lower(text or ""), "%S+") do
    table.insert(tokens, token)
  end
  return tokens
end

-- Configurable lexicons; callers may override these at runtime.
Analyzer.lexicons = {
  geo = {
    "drought", "flood", "earthquake", "wildfire", "famine",
    "sea-level", "blackout", "infrastructure", "heatwave", "storm"
  },
  eco = {
    "recession", "inflation", "default", "debt", "unemployment",
    "austerity", "hyperinflation", "bankrupt", "foreclosure", "shortage"
  },
  social = {
    "riot", "protest", "strike", "polarization", "civil",
    "refugee", "ethnic", "segregation", "lynching", "mob"
  },
  political = {
    "coup", "martial", "dictatorship", "corruption", "sanctions",
    "regime", "censorship", "emergency-law", "secret-police", "purge"
  },
  doom = {
    "inevitable", "nothing-we-can-do", "too-late", "doomed",
    "collapse-is-certain", "point-of-no-return", "hopeless"
  },
  agency = {
    "organize", "adapt", "mitigate", "reform", "resilience",
    "solidarity", "mutual-aid", "policy", "cooperate", "mobilize"
  }
}

local function count_matches(tokens, lexicon)
  local c = 0
  local lookup = {}
  for _, w in ipairs(lexicon) do
    lookup[w] = true
  end
  for _, t in ipairs(tokens) do
    if lookup[t] then
      c = c + 1
    end
  end
  return c
end

function Analyzer.extract_features(text)
  local t = Analyzer.tokenize(text)
  local f = {}
  f.G_raw      = count_matches(t, Analyzer.lexicons.geo)
  f.E_raw      = count_matches(t, Analyzer.lexicons.eco)
  f.S_raw      = count_matches(t, Analyzer.lexicons.social)
  f.P_raw      = count_matches(t, Analyzer.lexicons.political)
  f.D_neg_raw  = count_matches(t, Analyzer.lexicons.doom)
  f.D_pos_raw  = count_matches(t, Analyzer.lexicons.agency)
  f.length     = #t
  return f
end

----------------------------------------------------------------------
-- 3. Normalization hooks (delegate to repo’s canonical model)
----------------------------------------------------------------------

-- Placeholder: to be overridden at integration by canonical G/E/S/P mapper.
-- Expected contract: return a number in [0,1].
function Analyzer.normalize_indicator(raw, length, context)
  if length == 0 then return 0 end
  local freq = raw / length
  if freq < 0 then freq = 0 end
  if freq > 1 then freq = 1 end
  return freq
end

function Analyzer.compute_stress(features)
  local s = {}
  s.G = Analyzer.normalize_indicator(features.G_raw, features.length, "geo")
  s.E = Analyzer.normalize_indicator(features.E_raw, features.length, "eco")
  s.S = Analyzer.normalize_indicator(features.S_raw, features.length, "social")
  s.P = Analyzer.normalize_indicator(features.P_raw, features.length, "political")
  return s
end

----------------------------------------------------------------------
-- 4. Collapse risk scalar R(s) (without resilience)
----------------------------------------------------------------------

function Analyzer.collapse_risk(stress, weights, alpha)
  weights = weights or Analyzer.default_weights
  alpha   = alpha   or Analyzer.default_alpha
  local R = 0.0
  for dim, val in pairs(stress) do
    if val < 0 then val = 0 end
    if val > 1 then val = 1 end
    local w = weights[dim] or 1.0
    R = R + w * (val ^ alpha)
  end
  return R
end

----------------------------------------------------------------------
-- 5. Discourse-stress metric d_D
----------------------------------------------------------------------

function Analyzer.discourse_stress(features, epsilon)
  epsilon = epsilon or 1e-6
  local D_neg = features.D_neg_raw or 0
  local D_pos = features.D_pos_raw or 0
  local denom = D_neg + D_pos + epsilon
  local d_D   = D_neg / denom
  return {
    d_D   = d_D,
    D_neg = D_neg,
    D_pos = D_pos
  }
end

-- Qualitative labeling based on distribution-aware bands (no hard thresholds).
-- Caller can pass custom cutpoints learned from data; defaults are soft.
function Analyzer.label_discourse(d_D, bands)
  bands = bands or { low = 0.33, high = 0.66 }
  if d_D <= bands.low then
    return "agency-leaning with minimal doom"
  elseif d_D >= bands.high then
    return "doom-leaning with limited agency"
  else
    return "mixed / balanced"
  end
end

----------------------------------------------------------------------
-- 6. Relative-pattern helpers for conversational feedback
----------------------------------------------------------------------

-- Compare stress dimensions pairwise without thresholds.
function Analyzer.relative_patterns(stress_prev, stress_curr)
  local patterns = {}

  local function trend(dim)
    local prev = (stress_prev and stress_prev[dim]) or 0
    local curr = (stress_curr and stress_curr[dim]) or 0
    if curr > prev then
      return "rising"
    elseif curr < prev then
      return "falling"
    else
      return "stable"
    end
  end

  patterns.G_trend = trend("G")
  patterns.E_trend = trend("E")
  patterns.S_trend = trend("S")
  patterns.P_trend = trend("P")

  -- Relative emphasis at the current step (no absolute cutoff).
  local max_dim, max_val = nil, -1
  for dim, val in pairs(stress_curr or {}) do
    if val > max_val then
      max_val = val
      max_dim = dim
    end
  end
  patterns.dominant_dim = max_dim

  return patterns
end

----------------------------------------------------------------------
-- 7. High-level entrypoint
----------------------------------------------------------------------

function Analyzer.analyze(text, opts)
  opts = opts or {}
  local weights    = opts.weights
  local alpha      = opts.alpha
  local resilience = opts.resilience -- optional vector
  local prev       = opts.prev_stress

  local f        = Analyzer.extract_features(text)
  local stress   = Analyzer.compute_stress(f)
  local risk     = Analyzer.collapse_risk(stress, weights, alpha)
  local eff_risk = Analyzer.effective_risk(stress, resilience, weights, alpha)
  local disc     = Analyzer.discourse_stress(f)
  local label    = Analyzer.label_discourse(disc.d_D, opts.discourse_bands)
  local patterns = Analyzer.relative_patterns(prev, stress)

  return {
    features        = f,
    stress          = stress,       -- numeric G/E/S/P in [0,1]
    risk            = risk,        -- scalar R(s)
    effective_risk  = eff_risk,    -- scalar C(s,r)
    discourse       = disc,        -- d_D plus counts
    discourse_label = label,       -- qualitative
    patterns        = patterns     -- relative changes, dominant dim
  }
end

return Analyzer
