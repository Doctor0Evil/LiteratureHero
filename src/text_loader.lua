local text_loader = {}

local function load_file(path)
  local fh, err = io.open(path, "r")
  if not fh then
    error("Cannot open file: " .. tostring(path) .. " / " .. tostring(err))
  end
  local content = fh:read("*a")
  fh:close()
  return content
end

function text_loader.load_documents(paths)
  local docs = {}
  for i, path in ipairs(paths) do
    local content = load_file(path)
    docs[#docs + 1] = {
      id = "doc_" .. i,
      path = path,
      content = content
    }
  end
  return docs
end

return text_loader
