-- src/tools/event_handler.lua
--
-- Simple event bus for LiteratureHero.
-- Lets you register handlers and dispatch events produced by
-- event_generator or other modules.

local event_handler = {}

local listeners = {}

----------------------------------------------------------------------
-- Register a handler for a given event type
--
-- type: string (e.g., "RISK_INDEX", "HOAX_STRUCTURE_STRONG")
-- fn: function(event) end
----------------------------------------------------------------------

function event_handler.on(type_name, fn)
  if not type_name or type(type_name) ~= "string" then
    error("event_handler.on: type_name must be a string")
  end
  if type(fn) ~= "function" then
    error("event_handler.on: handler must be a function")
  end

  listeners[type_name] = listeners[type_name] or {}
  table.insert(listeners[type_name], fn)
end

----------------------------------------------------------------------
-- Remove all handlers for a given event type (optional helper)
----------------------------------------------------------------------

function event_handler.clear(type_name)
  if type_name then
    listeners[type_name] = nil
  else
    listeners = {}
  end
end

----------------------------------------------------------------------
-- Dispatch a single event:
-- event = { type = "RISK_INDEX", severity = "...", message = "...", data = {...} }
----------------------------------------------------------------------

function event_handler.emit(event)
  if not event or type(event.type) ~= "string" then
    return
  end

  local group = listeners[event.type]
  if not group then
    return
  end

  for _, fn in ipairs(group) do
    fn(event)
  end
end

----------------------------------------------------------------------
-- Dispatch a list of events
----------------------------------------------------------------------

function event_handler.emit_all(events)
  for _, e in ipairs(events or {}) do
    event_handler.emit(e)
  end
end

return event_handler
