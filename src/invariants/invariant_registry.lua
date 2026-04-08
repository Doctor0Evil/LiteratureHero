local inv_unity = require("invariants.invariant_unity_hivemind")
local inv_tech = require("invariants.invariant_tech_gatekeeping")
local inv_utopian = require("invariants.invariant_utopian_weaponized")
local inv_doomsday = require("invariants.invariant_doomsday_sacred")

local registry = {
  unity_hivemind = inv_unity,
  tech_gatekeeping = inv_tech,
  utopian_principles_weaponized = inv_utopian,
  doomsday_sacred_combo = inv_doomsday
}

local invariant_registry = {}

function invariant_registry.list()
  local names = {}
  for k, _ in pairs(registry) do
    names[#names + 1] = k
  end
  table.sort(names)
  return names
end

function invariant_registry.evaluate_all(tokens, spec)
  local results = {}
  for name, mod in pairs(registry) do
    local res = mod.evaluate(tokens, spec)
    res.name = name
    results[#results + 1] = res
  end
  return results
end

return invariant_registry
