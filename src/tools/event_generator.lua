-- src/tools/event_generator.lua
--
-- Turn analysis results into higher-level "events":
-- narrative hooks, risk alerts, and hoax warnings that can
-- be used in timelines, dashboards, or scenario simulations.

local event_generator = {}

----------------------------------------------------------------------
-- Utility: small helper to safely format numbers
----------------------------------------------------------------------

local function fmt(num)
  if type(num) ~= "number" then
    return "0.00"
  end
  return string.format("%.2f", num)
end

----------------------------------------------------------------------
-- Event type 1: High-risk invariant combinations
----------------------------------------------------------------------

local function generate_invariant_events(analysis_result)
  local events = {}
  local invs = analysis_result.invariants or {}

  -- Build simple lookup
  local by_name = {}
  for _, inv in ipairs(invs) do
    if inv.name then
      by_name[inv.name] = inv
    end
  end

  local function get_norm(name)
    local obj = by_name[name]
    if obj and type(obj.normalized) == "number" then
      return obj.normalized
    end
    return 0
  end

  -- Example: Unity + Tech Gatekeeping + Utopian Principles
  local u = get_norm("unity_hivemind")
  local t = get_norm("tech_gatekeeping")
  local up = get_norm("utopian_principles_weaponized")

  local combo_score = (u + t + up) / 3.0

  if combo_score >= 0.6 then
    events[#events + 1] = {
      type = "HIGH_RISK_COMBINATION",
      severity = "high",
      message = "Dangerous convergence: Hive-mind unity, technocratic gatekeeping, and utopian principles are all strong in this scenario.",
      data = {
        unity_hivemind = u,
        tech_gatekeeping = t,
        utopian_principles_weaponized = up,
        combo_score = combo_score
      }
    }
  elseif combo_score >= 0.4 then
    events[#events + 1] = {
      type = "ELEVATED_RISK_COMBINATION",
      severity = "medium",
      message = "Elevated convergence of unity, tech gatekeeping, and utopian principles detected.",
      data = {
        unity_hivemind = u,
        tech_gatekeeping = t,
        utopian_principles_weaponized = up,
        combo_score = combo_score
      }
    }
  end

  return events
end

----------------------------------------------------------------------
-- Event type 2: Risk index alerts (from risk_scorer)
----------------------------------------------------------------------

local function generate_risk_index_events(analysis_result)
  local events = {}
  local indices = (analysis_result.risk_indices) or {}

  for name, value in pairs(indices) do
    local sev
    if value >= 0.75 then
      sev = "high"
    elseif value >= 0.5 then
      sev = "medium"
    elseif value >= 0.25 then
      sev = "low"
    else
      sev = nil
    end

    if sev then
      events[#events + 1] = {
        type = "RISK_INDEX",
        severity = sev,
        message = "Risk index '" .. name .. "' is at " .. fmt(value) .. ".",
        data = {
          index = name,
          value = value
        }
      }
    end
  end

  return events
end

----------------------------------------------------------------------
-- Event type 3: Hoax / epistemic fragility events
----------------------------------------------------------------------

local function generate_hoax_events(analysis_result)
  local events = {}

  local hoax_summary = analysis_result.hoax_summary or analysis_result.hoax_invariants
  if not hoax_summary then
    return events
  end

  local function get_norm(id)
    local inv = hoax_summary[id]
    if inv and type(inv.normalized) == "number" then
      return inv.normalized
    end
    return 0
  end

  local auth = get_norm("AUTHORITY_MASK")
  local chain = get_norm("CHAIN_OF_EVIDENCE")
  local edge = get_norm("EDGE_OF_BELIEVABILITY")
  local myth = get_norm("REFRAME_FOUNDING_MYTH")

  local avg = (auth + chain + edge + myth) / 4.0

  if avg >= 0.6 then
    events[#events + 1] = {
      type = "HOAX_STRUCTURE_STRONG",
      severity = "high",
      message = "Strong hoax-like structure detected: authority mask, chain-of-evidence, edge-of-believability, and founding myth reframing are all active.",
      data = {
        AUTHORITY_MASK = auth,
        CHAIN_OF_EVIDENCE = chain,
        EDGE_OF_BELIEVABILITY = edge,
        REFRAME_FOUNDING_MYTH = myth,
        average = avg
      }
    }
  elseif avg >= 0.4 then
    events[#events + 1] = {
      type = "HOAX_STRUCTURE_PRESENT",
      severity = "medium",
      message = "Hoax-like narrative structure present at moderate strength.",
      data = {
        AUTHORITY_MASK = auth,
        CHAIN_OF_EVIDENCE = chain,
        EDGE_OF_BELIEVABILITY = edge,
        REFRAME_FOUNDING_MYTH = myth,
        average = avg
      }
    }
  end

  return events
end

----------------------------------------------------------------------
-- Event type 4: Faction-level contrast events
----------------------------------------------------------------------

local function generate_faction_events(analysis_result)
  local events = {}
  local factions = analysis_result.factions or {}

  if #factions < 2 then
    return events
  end

  -- For simplicity, look at unity_hivemind and tech_gatekeeping variance
  local function get_score(f, inv_name)
    if f.scores and type(f.scores[inv_name]) == "number" then
      return f.scores[inv_name]
    end
    return 0
  end

  local max_diff_unity = 0
  local max_pair_unity = nil

  local max_diff_tech = 0
  local max_pair_tech = nil

  for i = 1, #factions do
    for j = i + 1, #factions do
      local a = factions[i]
      local b = factions[j]

      local ua = get_score(a, "unity_hivemind")
      local ub = get_score(b, "unity_hivemind")
      local diff_u = math.abs(ua - ub)

      if diff_u > max_diff_unity then
        max_diff_unity = diff_u
        max_pair_unity = { a = a, b = b, ua = ua, ub = ub }
      end

      local ta = get_score(a, "tech_gatekeeping")
      local tb = get_score(b, "tech_gatekeeping")
      local diff_t = math.abs(ta - tb)

      if diff_t > max_diff_tech then
        max_diff_tech = diff_t
        max_pair_tech = { a = a, b = b, ta = ta, tb = tb }
      end
    end
  end

  if max_pair_unity and max_diff_unity >= 0.3 then
    events[#events + 1] = {
      type = "FACTION_AUTONOMY_CONTRAST",
      severity = "info",
      message = "Significant difference in hive-mind / unity patterns between factions '" ..
        (max_pair_unity.a.label or max_pair_unity.a.id) .. "' and '" ..
        (max_pair_unity.b.label or max_pair_unity.b.id) .. "'.",
      data = {
        faction_a = max_pair_unity.a.id,
        faction_b = max_pair_unity.b.id,
        unity_a = max_pair_unity.ua,
        unity_b = max_pair_unity.ub,
        diff = max_diff_unity
      }
    }
  end

  if max_pair_tech and max_diff_tech >= 0.3 then
    events[#events + 1] = {
      type = "FACTION_TECH_CAPTURE_CONTRAST",
      severity = "info",
      message = "Significant difference in tech gatekeeping between factions '" ..
        (max_pair_tech.a.label or max_pair_tech.a.id) .. "' and '" ..
        (max_pair_tech.b.label or max_pair_tech.b.id) .. "'.",
      data = {
        faction_a = max_pair_tech.a.id,
        faction_b = max_pair_tech.b.id,
        tech_a = max_pair_tech.ta,
        tech_b = max_pair_tech.tb,
        diff = max_diff_tech
      }
    }
  end

  return events
end

----------------------------------------------------------------------
-- Public API: generate all events for one analysis_result
----------------------------------------------------------------------

function event_generator.generate(analysis_result)
  local events = {}

  local function append(list)
    for _, e in ipairs(list) do
      events[#events + 1] = e
    end
  end

  append(generate_invariant_events(analysis_result))
  append(generate_risk_index_events(analysis_result))
  append(generate_hoax_events(analysis_result))
  append(generate_faction_events(analysis_result))

  return events
end

----------------------------------------------------------------------
-- Optional: render events as markdown bullets for reports
----------------------------------------------------------------------

function event_generator.to_markdown(events)
  if not events or #events == 0 then
    return "## Key Events\n\n_(no notable events detected)_"
  end

  local lines = {}
  lines[#lines + 1] = "## Key Events"
  lines[#lines + 1] = ""

  for _, e in ipairs(events) do
    local sev = e.severity or "info"
    local label = "[" .. sev .. "] " .. (e.type or "EVENT")
    lines[#lines + 1] = "- **" .. label .. "** – " .. (e.message or "")
  end

  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

return event_generator
