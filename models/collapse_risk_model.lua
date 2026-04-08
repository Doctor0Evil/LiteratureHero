-- models/collapse_risk_model.lua

local CollapseModel = {}

-- Basic keyword patterns for each dimension.
-- In practice, replace with richer pattern sets or ML models.
local patterns = {
  G = { "flood", "drought", "blackout", "heatwave", "wildfire", "earthquake", "radiation" },
  E = { "unemployment", "inflation", "debt crisis", "food shortage", "supply chain", "bank run", "recession" },
  S = { "riot", "looting", "civil unrest", "hate crime", "terrorist", "gang violence", "polarization" },
  P = { "martial law", "coup", "censorship", "paramilitary", "secret police", "authoritarian", "corruption" }
}

local function count_matches(text, keyword_list)
  local count = 0
  local lowered = text:lower()
  for _, kw in ipairs(keyword_list) do
    if lowered:find(kw:lower(), 1, true) then
      count = count + 1
    end
  end
  return count
end

-- Map raw counts to 0–15 nibble values
local function normalize_count(count, max_count)
  if count <= 0 then return 0 end
  if count >= max_count then return 15 end
  return math.floor((count / max_count) * 15 + 0.5)
end

-- Score a single text fragment, return nibble scores and hex tag
function CollapseModel.score_fragment(text, max_count)
  max_count = max_count or 5

  local g_raw = count_matches(text, patterns.G)
  local e_raw = count_matches(text, patterns.E)
  local s_raw = count_matches(text, patterns.S)
  local p_raw = count_matches(text, patterns.P)

  local g = normalize_count(g_raw, max_count)
  local e = normalize_count(e_raw, max_count)
  local s = normalize_count(s_raw, max_count)
  local p = normalize_count(p_raw, max_count)

  local hex_tag = string.format("0x%X%X%X%X", g, e, s, p)

  local result = {
    raw = { G = g_raw, E = e_raw, S = s_raw, P = p_raw },
    nibble = { G = g, E = e, S = s, P = p },
    hex = hex_tag
  }

  return result
end

-- Convert nibble scores to normalized 0–1 stress scores
function CollapseModel.nibble_to_stress(nibble_scores)
  local stress = {}
  for dim, v in pairs(nibble_scores) do
    stress[dim] = v / 15.0
  end
  return stress
end

-- Composite collapse score C(t) with configurable weights
function CollapseModel.composite_score(stress_scores, weights)
  weights = weights or { G = 0.25, E = 0.25, S = 0.25, P = 0.25 }
  local C = 0.0
  for dim, s in pairs(stress_scores) do
    local w = weights[dim] or 0.0
    C = C + w * s
  end
  return C
end

return CollapseModel
