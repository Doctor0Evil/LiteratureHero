-- src/tools/simulation_runner.lua
--
-- Run lightweight simulations over existing analysis_result tables.
-- This does NOT re-parse text; it perturbs scores and re-aggregates
-- to see how robust collapse-risk conclusions are under different
-- assumptions and weights.

local simulation_runner = {}

----------------------------------------------------------------------
-- shallow copy helpers
----------------------------------------------------------------------

local function shallow_copy(t)
  local r = {}
  for k, v in pairs(t or {}) do
    r[k] = v
  end
  return r
end

local function copy_invariants(inv_list)
  local out = {}
  for i, inv in ipairs(inv_list or {}) do
    local c = {}
    for k, v in pairs(inv) do
      c[k] = v
    end
    out[i] = c
  end
  return out
end

----------------------------------------------------------------------
-- Apply a simple random perturbation to invariant normalized scores.
-- noise_level in [0,1]: 0.1 means +/- 0.1 uniform noise.
----------------------------------------------------------------------

local function perturb_invariants(invariants, noise_level)
  local out = copy_invariants(invariants)
  local nl = noise_level or 0

  if nl <= 0 then
    return out
  end

  for _, inv in ipairs(out) do
    if type(inv.normalized) == "number" then
      local delta = (math.random() * 2 - 1) * nl
      local v = inv.normalized + delta
      if v < 0 then v = 0 end
      if v > 1 then v = 1 end
      inv.normalized = v
    end
  end

  return out
end

----------------------------------------------------------------------
-- Recompute overall risk_score as simple average of invariants
-- (you can replace this with risk_scorer if you prefer).
----------------------------------------------------------------------

local function recompute_risk_score(invariants)
  local sum = 0
  local n = 0
  for _, inv in ipairs(invariants or {}) do
    if type(inv.normalized) == "number" then
      sum = sum + inv.normalized
      n = n + 1
    end
  end
  if n == 0 then return 0 end
  local v = sum / n
  if v < 0 then v = 0 end
  if v > 1 then v = 1 end
  return v
end

----------------------------------------------------------------------
-- Single simulation run:
--   - take a base analysis_result
--   - optionally perturb invariants
--   - recompute risk_score
--
-- options = {
--   noise_level = 0.0..1.0
-- }
----------------------------------------------------------------------

function simulation_runner.run_once(base_result, options)
  options = options or {}
  local noise_level = options.noise_level or 0

  local result = shallow_copy(base_result)
  result.invariants = perturb_invariants(base_result.invariants or {}, noise_level)
  result.risk_score = recompute_risk_score(result.invariants)

  return result
end

----------------------------------------------------------------------
-- Monte-Carlo style simulation:
-- run N times and summarize distribution of risk_score.
--
-- options = {
--   runs = 100,
--   noise_level = 0.1
-- }
----------------------------------------------------------------------

function simulation_runner.run_many(base_result, options)
  options = options or {}
  local runs = options.runs or 100
  local noise_level = options.noise_level or 0

  local scores = {}
  local min_s, max_s = 1, 0
  local sum = 0

  for i = 1, runs do
    local sim = simulation_runner.run_once(base_result, { noise_level = noise_level })
    local s = sim.risk_score or 0
    scores[#scores + 1] = s
    if s < min_s then min_s = s end
    if s > max_s then max_s = s end
    sum = sum + s
  end

  local mean = (runs > 0) and (sum / runs) or 0

  table.sort(scores)
  local median = 0
  if runs > 0 then
    if runs % 2 == 1 then
      median = scores[(runs + 1) / 2]
    else
      median = 0.5 * (scores[runs / 2] + scores[runs / 2 + 1])
    end
  end

  return {
    runs = runs,
    noise_level = noise_level,
    min = min_s,
    max = max_s,
    mean = mean,
    median = median,
    scores = scores
  }
end

----------------------------------------------------------------------
-- Optional: render simulation summary as markdown
----------------------------------------------------------------------

local function fmt(num)
  if type(num) ~= "number" then return "0.00" end
  return string.format("%.2f", num)
end

function simulation_runner.summary_to_markdown(summary, title)
  title = title or "Risk Simulation Summary"
  local lines = {}

  lines[#lines + 1] = "## " .. title
  lines[#lines + 1] = ""
  lines[#lines + 1] = "- Runs: " .. tostring(summary.runs or 0)
  lines[#lines + 1] = "- Noise level: " .. fmt(summary.noise_level or 0)
  lines[#lines + 1] = "- Min risk: " .. fmt(summary.min or 0)
  lines[#lines + 1] = "- Max risk: " .. fmt(summary.max or 0)
  lines[#lines + 1] = "- Mean risk: " .. fmt(summary.mean or 0)
  lines[#lines + 1] = "- Median risk: " .. fmt(summary.median or 0)
  lines[#lines + 1] = ""

  return table.concat(lines, "\n")
end

return simulation_runner
