local invariant_graph = {}

-- Simple hand-built graph: nodes are invariants, edges encode known dangerous interactions
local adjacency = {
  unity_hivemind = {
    utopian_principles_weaponized = 0.8,
    tech_gatekeeping = 0.7
  },
  tech_gatekeeping = {
    unity_hivemind = 0.7,
    doomsday_sacred_combo = 0.6
  },
  utopian_principles_weaponized = {
    unity_hivemind = 0.8,
    doomsday_sacred_combo = 0.9
  },
  doomsday_sacred_combo = {
    utopian_principles_weaponized = 0.9,
    tech_gatekeeping = 0.6
  }
}

function invariant_graph.build(invariants)
  local nodes = {}
  local index = {}
  for _, inv in ipairs(invariants) do
    index[inv.name] = inv
    nodes[#nodes + 1] = inv.name
  end

  local edges = {}
  for src, neighbors in pairs(adjacency) do
    if index[src] then
      for dst, weight in pairs(neighbors) do
        if index[dst] then
          local strength = (index[src].normalized + index[dst].normalized) / 2 * weight
          edges[#edges + 1] = {
            from = src,
            to = dst,
            base_weight = weight,
            strength = strength
          }
        end
      end
    end
  end

  return {
    nodes = nodes,
    edges = edges
  }
end

function invariant_graph.aggregate_risk(graph)
  local total = 0
  for _, e in ipairs(graph.edges) do
    total = total + e.strength
  end
  -- soft cap risk into [0,1]
  return math.min(1.0, total / 5.0)
end

return invariant_graph
