-- src/analysis/factions.lua

local invariant_registry = require("src.invariants.invariant_registry")

local factions = {}

-- factions_spec: {
--   {
--     id = "mycelium",
--     label = "Mycelium Cult",
--     doc_tokens = { ... }, -- same structure lh_engine uses
--     meta = { role = "cult", alignment = "order" }
--   },
--   ...
-- }
--
-- spec: the work spec (id, title, etc.) passed through for context
function factions.analyze_factions(factions_spec, spec)
  local results = {}

  for _, f in ipairs(factions_spec or {}) do
    local inv_results = invariant_registry.evaluate_all(f.doc_tokens, spec)

    -- Build a simple map name -> normalized score for quick comparison
    local score_map = {}
    for _, inv in ipairs(inv_results) do
      score_map[inv.name] = inv.normalized or 0
    end

    results[#results + 1] = {
      id = f.id,
      label = f.label,
      meta = f.meta or {},
      invariants = inv_results,
      scores = score_map
    }
  end

  return results
end

-- Convenience: build a markdown table comparing key invariants across factions.
-- You can call this inside report_markdown if desired.
function factions.to_markdown_table(faction_results, invariant_order)
  if not faction_results or #faction_results == 0 then
    return "*(no faction data)*"
  end

  -- Determine which invariants to show (columns)
  local cols = {}
  if invariant_order and #invariant_order > 0 then
    cols = invariant_order
  else
    local seen = {}
    for _, fr in ipairs(faction_results) do
      for name, _ in pairs(fr.scores or {}) do
        if not seen[name] then
          seen[name] = true
          cols[#cols + 1] = name
        end
      end
    end
    table.sort(cols)
  end

  local lines = {}

  -- Header
  local header = "| Faction |"
  local sep = "| --- |"
  for _, c in ipairs(cols) do
    header = header .. " " .. c .. " |"
    sep = sep .. " --- |"
  end
  lines[#lines + 1] = header
  lines[#lines + 1] = sep

  -- Rows
  for _, fr in ipairs(faction_results) do
    local row = "| " .. (fr.label or fr.id) .. " |"
    for _, c in ipairs(cols) do
      local v = fr.scores[c]
      if v then
        row = row .. " " .. string.format("%.2f", v) .. " |"
      else
        row = row .. " 0.00 |"
      end
    end
    lines[#lines + 1] = row
  end

  return table.concat(lines, "\n")
end

return factions
