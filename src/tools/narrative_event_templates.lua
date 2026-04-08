-- src/tools/narrative_event_templates.lua
--
-- Turn structured events into short narrative descriptions
-- suitable for reports, timelines, or educational output.

local templates = {}

----------------------------------------------------------------------
-- Internal: per-type template functions
-- Each function receives (event, context) and returns a string.
-- context may include work_id, title, faction labels, etc.
----------------------------------------------------------------------

local function tmpl_high_risk_combo(event, context)
  local title = context and context.title or "this scenario"
  local d = event.data or {}
  return "In " .. title .. ", a dangerous blend of hive-mind unity (" ..
    string.format("%.2f", d.unity_hivemind or 0) ..
    "), technocratic gatekeeping (" ..
    string.format("%.2f", d.tech_gatekeeping or 0) ..
    "), and weaponized utopian principles (" ..
    string.format("%.2f", d.utopian_principles_weaponized or 0) ..
    ") suggests that basic autonomy could be traded away in the name of order and charity."
end

local function tmpl_risk_index(event, context)
  local title = context and context.title or "this scenario"
  local d = event.data or {}
  local idx = d.index or "unknown index"
  return "The " .. idx .. " in " .. title ..
    " is elevated at " .. string.format("%.2f", d.value or 0) ..
    ", indicating structural pressure toward that specific failure mode."
end

local function tmpl_hoax_strong(event, context)
  local title = context and context.title or "this scenario"
  return "Narratives in " .. title ..
    " show a strong hoax-like structure: calm experts, pseudo-rigorous evidence chains, and radical reinterpretations of founding events make disinformation highly plausible to in-world audiences."
end

local function tmpl_faction_autonomy(event, context)
  local d = event.data or {}
  local a = d.faction_a or "Faction A"
  local b = d.faction_b or "Faction B"
  return "Autonomy risk is unevenly distributed: " .. a .. " leans far more toward hive-mind unity than " ..
    b .. ", creating asymmetrical pressure on individuals depending on which group they join."
end

local function tmpl_faction_tech(event, context)
  local d = event.data or {}
  local a = d.faction_a or "Faction A"
  local b = d.faction_b or "Faction B"
  return "Control over critical technology is sharply asymmetric: " .. a ..
    " concentrates access much more tightly than " .. b ..
    ", increasing the danger of technocratic capture if " .. a .. " prevails."
end

----------------------------------------------------------------------
-- Public: render a single event using narrative templates
----------------------------------------------------------------------

function templates.render_event(event, context)
  if not event or not event.type then
    return ""
  end

  if event.type == "HIGH_RISK_COMBINATION" or event.type == "ELEVATED_RISK_COMBINATION" then
    return tmpl_high_risk_combo(event, context)
  elseif event.type == "RISK_INDEX" then
    return tmpl_risk_index(event, context)
  elseif event.type == "HOAX_STRUCTURE_STRONG" or event.type == "HOAX_STRUCTURE_PRESENT" then
    return tmpl_hoax_strong(event, context)
  elseif event.type == "FACTION_AUTONOMY_CONTRAST" then
    return tmpl_faction_autonomy(event, context)
  elseif event.type == "FACTION_TECH_CAPTURE_CONTRAST" then
    return tmpl_faction_tech(event, context)
  end

  -- Fallback: use the raw message
  return event.message or ""
end

----------------------------------------------------------------------
-- Public: render a list of events into markdown paragraphs
----------------------------------------------------------------------

function templates.render_all(events, context)
  local lines = {}

  for _, e in ipairs(events or {}) do
    local txt = templates.render_event(e, context)
    if txt and txt ~= "" then
      lines[#lines + 1] = "- " .. txt
    end
  end

  if #lines == 0 then
    return "*(no narrative events)*"
  end

  return table.concat(lines, "\n")
end

return templates
