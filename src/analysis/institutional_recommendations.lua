local M = {}

local function recommendation_unity(inv)
  if inv.normalized < 0.3 then return nil end
  return {
    invariant = inv.name,
    priority = "high",
    summary = "Independent pluralism safeguards against hive-mind dynamics.",
    measures = {
      "Mandate autonomous councils or boards that cannot be dissolved by any single leader or faction.",
      "Require explicit opt-out and exit rights for members of any mass movement providing essential services.",
      "Fund competing organizations that offer community and meaning without demanding personality dissolution."
    }
  }
end

local function recommendation_tech(inv)
  if inv.normalized < 0.3 then return nil end
  return {
    invariant = inv.name,
    priority = "high",
    summary = "Decentralize control over critical technical systems.",
    measures = {
      "Separate operational, audit, and policy roles for critical infrastructure stewards.",
      "Introduce citizen oversight panels with read-access to logs and decisions of technical elites.",
      "Legally prohibit single-faction monopoly over core survival systems (water, power, communications)."
    }
  }
end

local function recommendation_utopian(inv)
  if inv.normalized < 0.3 then return nil end
  return {
    invariant = inv.name,
    priority = "medium",
    summary = "Maintain transparency around trade-offs claimed in the name of higher ideals.",
    measures = {
      "Require public justification and time-limited review for any emergency powers claimed for 'the greater good'.",
      "Enforce independent ombudsman offices to receive anonymous complaints from movement members.",
      "Audit charitable organizations for coercive conditions tied to aid distribution."
    }
  }
end

local function recommendation_doomsday(inv)
  if inv.normalized < 0.3 then return nil end
  return {
    invariant = inv.name,
    priority = "high",
    summary = "Defuse sacralized doomsday narratives before they rationalize violence.",
    measures = {
      "Monitor high-intensity apocalyptic rhetoric in groups with access to weapons or critical infrastructure.",
      "Provide off-ramps for members through counseling, deradicalization, and alternative meaning frameworks.",
      "Restrict access to weapons for organizations whose texts explicitly couple purification with mass harm."
    }
  }
end

local dispatch = {
  unity_hivemind = recommendation_unity,
  tech_gatekeeping = recommendation_tech,
  utopian_principles_weaponized = recommendation_utopian,
  doomsday_sacred_combo = recommendation_doomsday
}

function M.from_invariants(invariants, graph, spec)
  local recs = {}
  for _, inv in ipairs(invariants) do
    local fn = dispatch[inv.name]
    if fn then
      local r = fn(inv)
      if r then
        recs[#recs + 1] = r
      end
    end
  end
  return {
    context = {
      work_id = spec.id,
      title = spec.title,
      tags = spec.tags
    },
    recommendations = recs
  }
end

return M
