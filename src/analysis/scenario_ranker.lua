-- src/analysis/scenario_ranker.lua

local ranker = {}

-- Internal helper: build a map name -> normalized score from an invariants array
local function build_invariant_map(invariants)
  local m = {}
  for _, inv in ipairs(invariants or {}) do
    if inv.name and inv.normalized then
      m[inv.name] = inv.normalized
    end
  end
  return m
end

-- Compute a "collapse proximity" score from invariant map.
-- You can tune this weighting to emphasize particular invariants.
local function compute_collapse_proximity(inv_map, weights)
  local total_w = 0
  local acc = 0

  for name, w in pairs(weights or {}) do
    local v = inv_map[name] or 0
    acc = acc + v * w
    total_w = total_w + w
  end

  if total_w == 0 then
    return 0.0
  end

  local score = acc / total_w
  if score < 0 then score = 0 end
  if score > 1 then score = 1 end
  return score
end

-- scenarios: array of analysis_result tables, each like:
-- {
--   spec = { id = "...", title = "..." },
--   risk_score = 0.0..1.0,
--   invariants = { {name, normalized, ...}, ... }
-- }
--
-- weights: optional table of invariant weights, e.g.:
-- {
--   unity_hivemind = 1.0,
--   tech_gatekeeping = 0.8,
--   utopian_principles_weaponized = 0.7,
--   doomsday_sacred_combo = 1.0
-- }
function ranker.rank_scenarios(scenarios, weights)
  local ranked = {}

  for _, s in ipairs(scenarios or {}) do
    local inv_map = build_invariant_map(s.invariants)
    local proximity = compute_collapse_proximity(inv_map, weights or {})

    ranked[#ranked + 1] = {
      id = s.spec and s.spec.id or "unknown",
      title = s.spec and s.spec.title or "Unknown Scenario",
      risk_score = s.risk_score or 0.0,
      collapse_proximity = proximity,
      inv_map = inv_map
    }
  end

  table.sort(ranked, function(a, b)
    if a.collapse_proximity == b.collapse_proximity then
      return (a.risk_score or 0) > (b.risk_score or 0)
    end
    return a.collapse_proximity > b.collapse_proximity
  end)

  return ranked
end

-- Convenience: pretty markdown table of ranked scenarios.
function ranker.to_markdown_table(ranked)
  if not ranked or #ranked == 0 then
    return "*(no scenarios to rank)*"
  end

  local lines = {}
  lines[#lines + 1] = "| Rank | Scenario | Collapse Proximity | Overall Risk |"
  lines[#lines + 1] = "| --- | --- | --- | --- |"

  for i, r in ipairs(ranked) do
    lines[#lines + 1] = "| " .. i ..
      " | " .. r.title ..
      " | " .. string.format("%.2f", r.collapse_proximity) ..
      " | " .. string.format("%.2f", r.risk_score or 0) ..
      " |"
  end

  return table.concat(lines, "\n")
end

return ranker
