-- src/analysis/faction_comparator.lua
--
-- Compare multiple factions within a single work across invariants.
-- Designed to work with LiteratureHero's invariant modules.

local faction_comparator = {}

----------------------------------------------------------------------
-- Build a map name -> normalized score from an invariant result list
----------------------------------------------------------------------

local function build_score_map(invariants)
  local m = {}
  for _, inv in ipairs(invariants or {}) do
    if inv.name and type(inv.normalized) == "number" then
      m[inv.name] = inv.normalized
    end
  end
  return m
end

----------------------------------------------------------------------
-- Core: construct comparison structure
--
-- factions_input: {
--   {
--     id = "mycelium",
--     label = "Mycelium Cult",
--     invariants = { {name="unity_hivemind", normalized=0.9, ...}, ... },
--     meta = { role = "cult", alignment = "order" }
--   },
--   {
--     id = "atom_org",
--     label = "ATOM Organization",
--     invariants = { ... },
--     meta = { role = "agency" }
--   },
--   ...
-- }
----------------------------------------------------------------------

function faction_comparator.compare(factions_input)
  local results = {}
  local all_invariant_names = {}

  local seen = {}

  for _, f in ipairs(factions_input or {}) do
    local scores = build_score_map(f.invariants)
    results[#results + 1] = {
      id = f.id,
      label = f.label or f.id,
      meta = f.meta or {},
      invariants = f.invariants or {},
      scores = scores
    }

    for name, _ in pairs(scores) do
      if not seen[name] then
        seen[name] = true
        all_invariant_names[#all_invariant_names + 1] = name
      end
    end
  end

  table.sort(all_invariant_names)

  return {
    factions = results,
    invariants = all_invariant_names
  }
end

----------------------------------------------------------------------
-- Markdown rendering
--
-- comparison: result of faction_comparator.compare(...)
-- invariant_order (optional): array to fix column order
----------------------------------------------------------------------

function faction_comparator.to_markdown(comparison, invariant_order)
  if not comparison or not comparison.factions or #comparison.factions == 0 then
    return "*(no faction data)*"
  end

  local cols = {}

  if invariant_order and #invariant_order > 0 then
    cols = invariant_order
  else
    cols = comparison.invariants or {}
  end

  if #cols == 0 then
    return "*(no invariant scores to compare)*"
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
  for _, fr in ipairs(comparison.factions) do
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

return faction_comparator
