local M = {}

local function escape_str(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub("\"", "\\\"")
  s = s:gsub("\n", "\\n")
  return s
end

local function encode_value(v)
  local t = type(v)
  if t == "string" then
    return "\"" .. escape_str(v) .. "\""
  elseif t == "number" then
    return tostring(v)
  elseif t == "boolean" then
    return v and "true" or "false"
  elseif t == "table" then
    local is_array = true
    local idx = 1
    for k, _ in pairs(v) do
      if k ~= idx then
        is_array = false
        break
      end
      idx = idx + 1
    end
    if is_array then
      local parts = {}
      for i = 1, #v do
        parts[#parts + 1] = encode_value(v[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, vv in pairs(v) do
        parts[#parts + 1] = "\"" .. escape_str(k) .. "\":" .. encode_value(vv)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    return "null"
  end
end

function M.to_json(result)
  return encode_value(result)
end

return M
