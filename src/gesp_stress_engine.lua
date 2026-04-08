-- src/gesp_stress_engine.lua
-- Dimension-stress engine for LiteratureHero (G, E, S, P)
-- Responsibilities:
--   - Tokenization
--   - Lexicon-based feature extraction per dimension
--   - Normalization hooks: raw counts -> s_D ∈ [0,1]
--   - Hex 0xGESP encoding/decoding and nibble <-> stress conversion
--
-- This module is intentionally pure and threshold-free.
-- Downstream components handle risk bands, claim types, and debunking.

local StressEngine = {}

----------------------------------------------------------------------
-- 0. Config: lexicons and normalization hooks
----------------------------------------------------------------------

-- Minimal default lexicons. Replace/extend from config files in practice.
StressEngine.lexicons = {
  G = { "flood", "drought", "heatwave", "wildfire", "blackout", "grid", "famine",
        "radiation", "contamination", "hurricane", "earthquake", "tsunami" },
  E = { "unemployment", "inflation", "recession", "depression", "default",
        "bank run", "food shortage", "shortage", "austerity", "hyperinflation",
        "foreclosure", "bankrupt", "eviction" },
  S = { "riot", "looting", "lynching", "civil unrest", "hate crime", "pogrom",
        "gang violence", "polarization", "ethnic cleansing", "civil war",
        "xenophobia", "segregation" },
  P = { "coup", "martial law", "emergency decree", "dictator", "authoritarian",
        "secret police", "paramilitary", "military rule", "corruption",
        "purge", "one-party", "suspension of constitution" }
}

-- Optional: per-dimension maximum counts for nibble scaling (soft saturation).
StressEngine.max_counts = {
  G = 5,
  E = 5,
  S = 5,
  P = 5
}

-- Normalization hook: map indicator x in [x_low, x_high] to s ∈ [0,1].
-- Used conceptually for alignment with the canonical GESP model spec.
-- For this engine, we apply it to lexical counts after a crude rescale.
local function linear_normalize(x, x_low, x_high)
  if x_high <= x_low then
    return 0.0
  end
  local s = (x - x_low) / (x_high - x_low)
  if s < 0 then s = 0 end
  if s > 1 then s = 1 end
  return s
end

-- Hook that callers can override to align with the canonical mapping
-- from raw features to s_D ∈ [0,1].
-- Signature: normalize_indicator(dim, raw_count, length) -> s_D in [0,1].
function StressEngine.normalize_indicator(dim, raw_count, length)
  -- Simple default: treat raw_count as the "x" and 0..max_counts[dim] as range.
  local maxc = StressEngine.max_counts[dim] or 5
  return linear_normalize(raw_count, 0, maxc)
end

----------------------------------------------------------------------
-- 1. Tokenization and utility
----------------------------------------------------------------------

local function to_lower(s)
  return string.lower(s or "")
end

-- Simple whitespace tokenizer; split on non-alphabetic boundaries.
local function tokenize(text)
  local t = {}
  text = to_lower(text or "")
  for token in string.gmatch(text, "%w+") do
    t[#t + 1] = token
  end
  return t
end

-- Build a lookup set from a lexicon (list of words / phrases).
local function build_lookup(lex)
  local lut = {}
  for _, kw in ipairs(lex or {}) do
    lut[to_lower(kw)] = true
  end
  return lut
end

-- Cache lookup tables for performance.
local lex_luts = nil

local function ensure_lex_luts()
  if lex_luts then
    return lex_luts
  end
  lex_luts = { G = {}, E = {}, S = {}, P = {} }
  for dim, words in pairs(StressEngine.lexicons) do
    lex_luts[dim] = build_lookup(words)
  end
  return lex_luts
end

----------------------------------------------------------------------
-- 2. Feature extraction: extract_features(text) -> raw counts
----------------------------------------------------------------------

-- Simple heuristic: treat both single tokens and multiword phrases.
-- For phrases (with spaces), we fall back to substring search.
local function count_matches(text, lut, raw_list)
  local lowered = to_lower(text or "")
  local counts = 0

  -- Single-token matches via lookup.
  for token in string.gmatch(lowered, "%w+") do
    if lut[token] then
      counts = counts + 1
    end
  end

  -- Multiword phrases from raw_list (contains " ").
  for _, kw in ipairs(raw_list or {}) do
    if string.find(lowered, to_lower(kw), 1, true) and string.find(kw, " ") then
      counts = counts + 1
    end
  end

  return counts
end

-- Public API: extract_features(text)
-- Returns:
--   {
--      length = number (token count),
--      G_raw, E_raw, S_raw, P_raw = integer counts
--   }
function StressEngine.extract_features(text)
  local tokens = tokenize(text)
  local length = #tokens
  local luts = ensure_lex_luts()

  local G_raw = count_matches(text, luts.G, StressEngine.lexicons.G)
  local E_raw = count_matches(text, luts.E, StressEngine.lexicons.E)
  local S_raw = count_matches(text, luts.S, StressEngine.lexicons.S)
  local P_raw = count_matches(text, luts.P, StressEngine.lexicons.P)

  return {
    length = length,
    G_raw = G_raw,
    E_raw = E_raw,
    S_raw = S_raw,
    P_raw = P_raw
  }
end

----------------------------------------------------------------------
-- 3. Stress computation: compute_stress(features) -> sG, sE, sS, sP
----------------------------------------------------------------------

-- Public API: compute_stress(features)
-- Input:
--   features: table from extract_features
-- Output:
--   stress: { G = sG, E = sE, S = sS, P = sP } with s_D ∈ [0,1]
function StressEngine.compute_stress(features)
  local length = features.length or 0

  local sG = StressEngine.normalize_indicator("G", features.G_raw or 0, length)
  local sE = StressEngine.normalize_indicator("E", features.E_raw or 0, length)
  local sS = StressEngine.normalize_indicator("S", features.S_raw or 0, length)
  local sP = StressEngine.normalize_indicator("P", features.P_raw or 0, length)

  return { G = sG, E = sE, S = sS, P = sP }
end

----------------------------------------------------------------------
-- 4. Hex encoding / decoding: 0xGESP
----------------------------------------------------------------------

-- Clamp a value into [0, 15] and round to integer.
local function clamp_nibble(v)
  if v < 0 then v = 0 end
  if v > 15 then v = 15 end
  return math.floor(v + 0.5)
end

-- Map stress ∈ [0,1] to nibble ∈ {0..15}.
local function stress_to_nibble(s)
  if s < 0 then s = 0 end
  if s > 1 then s = 1 end
  return clamp_nibble(s * 15.0)
end

-- Map nibble ∈ {0..15} to stress ∈ [0,1].
local function nibble_to_stress(n)
  n = clamp_nibble(n)
  return n / 15.0
end

-- Encode per-dimension stress {G,E,S,P} into 0xGESP hex string.
function StressEngine.stress_to_hex(stress)
  local nG = stress_to_nibble(stress.G or 0.0)
  local nE = stress_to_nibble(stress.E or 0.0)
  local nS = stress_to_nibble(stress.S or 0.0)
  local nP = stress_to_nibble(stress.P or 0.0)
  return string.format("0x%1X%1X%1X%1X", nG, nE, nS, nP)
end

-- Decode 0xGESP hex string into nibble table {G,E,S,P}.
function StressEngine.hex_to_nibbles(hextag)
  if type(hextag) ~= "string" then
    return { G = 0, E = 0, S = 0, P = 0 }
  end
  -- Strip leading "0x" or "0X" if present.
  local clean = hextag:gsub("^0[xX]", "")
  if #clean < 4 then
    -- Pad left with zeros if needed.
    clean = string.rep("0", 4 - #clean) .. clean
  end
  local g = tonumber(clean:sub(1, 1), 16) or 0
  local e = tonumber(clean:sub(2, 2), 16) or 0
  local s = tonumber(clean:sub(3, 3), 16) or 0
  local p = tonumber(clean:sub(4, 4), 16) or 0
  return { G = g, E = e, S = s, P = p }
end

-- Convert hex tag directly to normalized stress scores in [0,1].
function StressEngine.hex_to_stress(hextag)
  local nibbles = StressEngine.hex_to_nibbles(hextag)
  return {
    G = nibble_to_stress(nibbles.G),
    E = nibble_to_stress(nibbles.E),
    S = nibble_to_stress(nibbles.S),
    P = nibble_to_stress(nibbles.P)
  }
end

-- Convert stress scores to nibble table without encoding as hex.
function StressEngine.stress_to_nibbles(stress)
  return {
    G = stress_to_nibble(stress.G or 0.0),
    E = stress_to_nibble(stress.E or 0.0),
    S = stress_to_nibble(stress.S or 0.0),
    P = stress_to_nibble(stress.P or 0.0)
  }
end

----------------------------------------------------------------------
-- 5. Convenience: one-shot analysis
----------------------------------------------------------------------

-- Public API: analyze(text)
-- Returns:
--   {
--     features = { length, G_raw, E_raw, S_raw, P_raw },
--     stress   = { G, E, S, P },
--     hextag   = "0xGESP",
--     nibbles  = { G, E, S, P }
--   }
function StressEngine.analyze(text)
  local feats = StressEngine.extract_features(text)
  local stress = StressEngine.compute_stress(feats)
  local hextag = StressEngine.stress_to_hex(stress)
  local nibbles = StressEngine.stress_to_nibbles(stress)
  return {
    features = feats,
    stress   = stress,
    hextag   = hextag,
    nibbles  = nibbles
  }
end

return StressEngine
