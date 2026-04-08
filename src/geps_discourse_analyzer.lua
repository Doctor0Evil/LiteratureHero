-- Filename: src/geps_discourse_analyzer.lua
-- Destination: /src/geps_discourse_analyzer.lua

local Analyzer = {}

-- 1. Tokenization and basic preprocessing
function Analyzer.tokenize(text)
  -- simple whitespace tokenizer; swap out for better NLP upstream
  local tokens = {}
  for token in string.gmatch(string.lower(text), "%S+") do
    table.insert(tokens, token)
  end
  return tokens
end

-- 2. Indicator dictionaries (loaded/configurable, not hard-coded thresholds)
Analyzer.lexicons = {
  geo = { "drought", "flood", "earthquake", "wildfire", "famine", "sea-level", "infrastructure" },
  eco = { "recession", "inflation", "default", "debt", "unemployment", "austerity", "hyperinflation" },
  social = { "riot", "protest", "strike", "polarization", "civil", "refugee", "ethnic", "segregation" },
  political = { "coup", "martial", "dictatorship", "corruption", "sanctions", "regime", "censorship" },
  doom = { "inevitable", "nothing-we-can-do", "too-late", "doomed", "collapse-is-certain" },
  agency = { "organize", "adapt", "mitigate", "reform", "resilience", "solidarity", "mutual-aid", "policy" }
}

-- 3. Lexicon-based feature extraction
local function count_matches(tokens, lexicon)
  local c = 0
  local lookup = {}
  for _, w in ipairs(lexicon) do lookup[w] = true end
  for _, t in ipairs(tokens) do
    if lookup[t] then c = c + 1 end
  end
  return c
end

function Analyzer.extract_features(text)
  local t = Analyzer.tokenize(text)
  local f = {}
  f.G_raw = count_matches(t, Analyzer.lexicons.geo)
  f.E_raw = count_matches(t, Analyzer.lexicons.eco)
  f.S_raw = count_matches(t, Analyzer.lexicons.social)
  f.P_raw = count_matches(t, Analyzer.lexicons.political)
  f.D_neg_raw = count_matches(t, Analyzer.lexicons.doom)
  f.D_pos_raw = count_matches(t, Analyzer.lexicons.agency)
  f.length = #t
  return f
end

-- 4. Normalization hooks – these should call out to repo’s canonical functions
-- Here they are placeholders to be overridden at integration time.
function Analyzer.normalize_indicator(raw, length, context)
  -- e.g., frequency per 1000 tokens, transformed by repo's risk model
  if length == 0 then return 0 end
  local freq = raw / length
  -- context can carry dimension name and configuration
  return freq  -- actual mapping supplied by repository
end

function Analyzer.compute_stress(features)
  local s = {}
  s.G = Analyzer.normalize_indicator(features.G_raw, features.length, "geo")
  s.E = Analyzer.normalize_indicator(features.E_raw, features.length, "eco")
  s.S = Analyzer.normalize_indicator(features.S_raw, features.length, "social")
  s.P = Analyzer.normalize_indicator(features.P_raw, features.length, "political")
  return s
end

-- 5. Collapse risk (no hard-coded thresholds)
function Analyzer.collapse_risk(stress, weights, alpha)
  weights = weights or { G = 1.0, E = 1.0, S = 1.0, P = 1.0 }
  alpha = alpha or 2.0
  local R = 0.0
  for dim, val in pairs(stress) do
    local w = weights[dim] or 1.0
    R = R + w * (val ^ alpha)
  end
  return R
end

-- 6. Discourse-stress metric d_D
function Analyzer.discourse_stress(features, epsilon)
  epsilon = epsilon or 1e-6
  local D_neg = features.D_neg_raw
  local D_pos = features.D_pos_raw
  local denom = D_neg + D_pos + epsilon
  local d_D = D_neg / denom
  return {
    d_D = d_D,
    D_neg = D_neg,
    D_pos = D_pos
  }
end

-- 7. High-level analysis entrypoint
function Analyzer.analyze(text, weights, alpha)
  local f = Analyzer.extract_features(text)
  local stress = Analyzer.compute_stress(f)
  local risk = Analyzer.collapse_risk(stress, weights, alpha)
  local discourse = Analyzer.discourse_stress(f)
  return {
    features = f,
    stress = stress,
    risk = risk,
    discourse = discourse
  }
end

return Analyzer
