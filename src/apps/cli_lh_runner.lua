local lh_engine = require("lh_engine")
local report_md = require("report_markdown")
local export_json = require("io.export_json")

local function main(argv)
  if #argv < 2 then
    io.stderr:write("Usage: lua cli_lh_runner.lua <work_id> <title> <input_path> [output_prefix]\n")
    os.exit(1)
  end

  local work_id = argv[1]
  local title = argv[2]
  local input_path = argv[3]
  local prefix = argv[4] or ("output/" .. work_id)

  local spec = {
    id = work_id,
    title = title,
    source_files = { input_path },
    tags = {}
  }

  local result = lh_engine.analyze(spec)

  local md = report_md.to_markdown(result)
  local json = export_json.to_json(result)

  local md_path = prefix .. ".md"
  local json_path = prefix .. ".json"

  local fh_md = assert(io.open(md_path, "w"))
  fh_md:write(md)
  fh_md:close()

  local fh_json = assert(io.open(json_path, "w"))
  fh_json:write(json)
  fh_json:close()

  print("Written: " .. md_path .. " and " .. json_path)
end

main(arg)
