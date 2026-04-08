-- src/gesp_threshold_sweep.lua
-- Threshold sweep and calibration tool for the GESP claim-type classifier.
--
-- Responsibilities
--   - Iterate over a grid of rule thresholds θ for claim-type and dD bands.
--   - Run the classifier on the gold corpus via the validation harness adapter.
--   - Compute per-type F1, macro/micro F1, and confusion matrices.
--   - Track cost-sensitive loss using the existing metrics module.
--   - Use disagreement notes and key confusions (Moral Panic vs Everything-Is-Broken)
--     to run targeted sweeps and log which θ values fix those errors.
--   - Evaluate robustness across domains (fiction, news, social).
--   - Emit a JSON/CSV summary of the best θ* and per-domain metrics.
--
-- Invariants
--   - No thresholds hard-coded in classifier logic: all exposed here via config.
--   - Dimension-level metrics and doom/agency metrics computed first; claim-type
--     metrics evaluated on top of these primitives.
--   - Cost-sensitive loss prioritizes high S/P stress and doom-saturated discourse.

local json = require("dkjson")        -- Expect dkjson or similar in repo.
local Metrics = require("toolsevalmetricsandloss")  -- cost/F1/MAE utilities.
local ClaimClassifier = require("src.claimclassifier")
local Debias = require("src.gespdebiasanalyzer")
local Harness = require("src.gespvalidationharness") -- for loading corpus, adapters.

local ThresholdSweep = {}

----------------------------------------------------------------------
-- 0. Utility helpers
----------------------------------------------------------------------

local function deepcopy(tbl)
  if type(tbl) ~= "table" then return tbl end
  local res = {}
  for k, v in pairs(tbl) do
    res[k] = deepcopy(v)
  end
  return res
end

local function safediv(num, den)
  if not den or den == 0 then return 0 end
  return num / den
end

local function mkdir_p(path)
  -- Minimal portable mkdir; treat as no-op if already exists.
  os.execute(string.format("mkdir -p %q", path))
end

----------------------------------------------------------------------
-- 1. Threshold configuration space
--
-- θ vector encodes:
--   - t_dom: dominant-dimension cutoff for Single-Factor Doom.
--   - t_all: all-dimensions-high cutoff for Everything-Is-Broken.
--   - t_doom: doom-saturation cutoff for Single-Factor Doom / doom-heavy logic.
--   - dD_bands: low/high for agency-leaning vs doom-leaning.
--
-- These are passed into ClaimClassifier via configuration and into Debias
-- for dD banding, so that tuning is centralised here.
----------------------------------------------------------------------

local function default_theta_grid()
  return {
    t_dom = {0.4, 0.5, 0.6},
    t_all = {0.6, 0.7, 0.8},
    t_doom = {0.5, 0.6, 0.7},
    dD_low = {0.30, 0.35, 0.40},
    dD_high = {0.60, 0.65, 0.70},
  }
end

local function cartesian_product(grid)
  local keys = {"t_dom", "t_all", "t_doom", "dD_low", "dD_high"}
  local combos = {}

  local function recurse(i, current)
    if i > #keys then
      table.insert(combos, deepcopy(current))
      return
    end
    local k = keys[i]
    for _, v in ipairs(grid[k]) do
      current[k] = v
      recurse(i + 1, current)
    end
  end

  recurse(1, {})
  return combos
end

local function theta_id(theta)
  return string.format("tdom=%.2f_tall=%.2f_tdoom=%.2f_dlow=%.2f_dhigh=%.2f",
    theta.t_dom, theta.t_all, theta.t_doom, theta.dD_low, theta.dD_high)
end

----------------------------------------------------------------------
-- 2. Wiring thresholds into classifier and dD bands
----------------------------------------------------------------------

local function configure_stack_with_theta(theta)
  -- Configure dD bands on the debias analyzer.
  Debias.dDbands = {
    low = theta.dD_low,
    high = theta.dD_high,
  }

  -- Configure claim-type thresholds on the classifier.
  ClaimClassifier.thresholds = {
    t_dom = theta.t_dom,
    t_all = theta.t_all,
    t_doom = theta.t_doom,
    dD_low = theta.dD_low,
    dD_high = theta.dD_high,
  }
end

----------------------------------------------------------------------
-- 3. Gold corpus loading and domain splits
----------------------------------------------------------------------

local function load_gold(path)
  -- Delegate to harness loader if available; otherwise simple CSV/JSONL loader.
  -- Expect records to include:
  --   id, text, contextsource, claimtype (gold), isgold, disagreementnotes.
  return Harness.load_gold_corpus(path)
end

local function split_by_domain(records)
  local splits = {all = {}, fiction = {}, news = {}, social = {}}
  for _, rec in ipairs(records) do
    table.insert(splits.all, rec)
    local src = (rec.contextsource or rec.context or "other"):lower()
    if src == "fiction" then
      table.insert(splits.fiction, rec)
    elseif src == "news" then
      table.insert(splits.news, rec)
    elseif src == "social" or src == "forum" then
      table.insert(splits.social, rec)
    end
  end
  return splits
end

local function select_disagreement_subset(records)
  local subset = {}
  for _, rec in ipairs(records) do
    if rec.isgold and rec.disagreementnotes and rec.disagreementnotes ~= "" then
      table.insert(subset, rec)
    end
  end
  return subset
end

local function select_moralpanic_vs_eib(records)
  local subset = {}
  for _, rec in ipairs(records) do
    local ctype = rec.claimtype
    if ctype == "Moral Panic" or ctype == "Everything-Is-Broken" then
      table.insert(subset, rec)
    end
  end
  return subset
end

----------------------------------------------------------------------
-- 4. Running classifier with current θ
--
-- Adapter:
--   - Use Debias.analyzetext for sclaimed, dD, etc.
--   - Call ClaimClassifier.classifyclaim for claim-type prediction.
--   - Build arrays gold/sys for Metrics functions.
----------------------------------------------------------------------

local function run_classifier_on_records(records)
  local gold = {}
  local sys = {}

  for _, rec in ipairs(records) do
    local text = rec.text or ""
    local context = rec.context or rec
    local debias_out = Debias.analyzetext(text, context, {})
    local cls = ClaimClassifier.classifyclaim(text, {
      saopts = { },                     -- passthrough analyzer options if needed
      daopts = { },                     -- doom/agency options
      sestimated = debias_out.stressestimated,
    })

    table.insert(gold, {
      id = rec.id,
      claimtype = rec.claimtype,
      sclaimed = rec.sclaimed,
      Dgold = rec.delta,
      dDgold = rec.dDoverall,
      dDdimgold = rec.dDperdim,
      contextsource = rec.contextsource,
    })

    table.insert(sys, {
      id = rec.id,
      claimtypepred = cls.claimtype,
      spred = cls.raw and cls.raw.stressclaimed or debias_out.stressclaimed,
      Dpred = cls.raw and cls.raw.distortion or debias_out.delta,
      dDpred = cls.raw and cls.raw.doverall or debias_out.dDoverall,
      dDdimpred = cls.raw and cls.raw.dperdim or debias_out.dDperdim,
      contextsource = rec.contextsource,
    })
  end

  return gold, sys
end

----------------------------------------------------------------------
-- 5. Metrics for a given θ on a given subset
----------------------------------------------------------------------

local function evaluate_theta_on_subset(theta, records, cost_weights)
  configure_stack_with_theta(theta)
  local gold, sys = run_classifier_on_records(records)

  -- Dimension stress/dD metrics.
  local mae = Metrics.computemae(gold, sys)
  local hs = Metrics.computehighstressmetrics(gold, sys, {tau = 0.5})
  local macroF1, pertype = Metrics.computeclaimtypemacrof1(gold, sys)
  local loss = Metrics.computecostloss(gold, sys, cost_weights or {})

  return {
    theta = deepcopy(theta),
    macroF1 = macroF1,
    pertype = pertype,
    mae = mae,
    highstress = hs,
    cost = loss.total_cost,
    cost_breakdown = loss.breakdown,
    gold_size = #gold,
  }, gold, sys
end

----------------------------------------------------------------------
-- 6. Confusion matrices for claim types
----------------------------------------------------------------------

local function confusion_matrix_claimtype(gold, sys)
  local labels = {}
  for i = 1, #gold do
    labels[gold[i].claimtype] = true
    labels[sys[i].claimtypepred] = true
  end
  local types = {}
  for t, _ in pairs(labels) do table.insert(types, t) end

  local mat = {}
  for _, gt in ipairs(types) do
    mat[gt] = {}
    for _, pt in ipairs(types) do
      mat[gt][pt] = 0
    end
  end

  for i = 1, #gold do
    local gt = gold[i].claimtype
    local pt = sys[i].claimtypepred
    if not mat[gt] then mat[gt] = {} end
    if not mat[gt][pt] then mat[gt][pt] = 0 end
    mat[gt][pt] = mat[gt][pt] + 1
  end

  return {types = types, matrix = mat}
end

----------------------------------------------------------------------
-- 7. Targeted sweeps for disagreement / Moral Panic vs Everything-Is-Broken
--
-- For selected subsets, we track how many gold mislabels are resolved
-- under each θ, especially confusion between Moral Panic and Everything-Is-Broken.
----------------------------------------------------------------------

local function targeted_error_analysis(theta, records)
  configure_stack_with_theta(theta)
  local gold, sys = run_classifier_on_records(records)

  local fixed_moralpanic_eib = 0
  local total_moralpanic_eib = 0
  local fixed_any_disagreement = 0
  local total_any_disagreement = #records

  for i = 1, #gold do
    local g = gold[i]
    local s = sys[i]
    local gt = g.claimtype
    local pt = s.claimtypepred

    if gt == "Moral Panic" or gt == "Everything-Is-Broken" then
      total_moralpanic_eib = total_moralpanic_eib + 1
      if pt == gt then
        fixed_moralpanic_eib = fixed_moralpanic_eib + 1
      end
    end

    if pt == gt then
      fixed_any_disagreement = fixed_any_disagreement + 1
    end
  end

  return {
    theta = deepcopy(theta),
    fixed_moralpanic_eib = fixed_moralpanic_eib,
    total_moralpanic_eib = total_moralpanic_eib,
    moralpanic_eib_fix_rate = safediv(fixed_moralpanic_eib, total_moralpanic_eib),
    fixed_any_disagreement = fixed_any_disagreement,
    total_any_disagreement = total_any_disagreement,
    disagreement_fix_rate = safediv(fixed_any_disagreement, total_any_disagreement),
  }
end

----------------------------------------------------------------------
-- 8. Domain-specific robustness evaluation
----------------------------------------------------------------------

local function evaluate_theta_across_domains(theta, splits, cost_weights)
  local domain_results = {}
  for name, recs in pairs(splits) do
    if #recs > 0 then
      local res = evaluate_theta_on_subset(theta, recs, cost_weights)
      domain_results[name] = res
    end
  end
  return domain_results
end

----------------------------------------------------------------------
-- 9. Global sweep procedure
----------------------------------------------------------------------

function ThresholdSweep.run(args)
  args = args or {}
  local gold_path = args.gold_path or "data/corpus_gold.jsonl"
  local out_dir = args.out_dir or "output/threshold_sweep"
  local grid = args.grid or default_theta_grid()

  mkdir_p(out_dir)

  local all_records = load_gold(gold_path)
  local splits = split_by_domain(all_records)
  local disagreements = select_disagreement_subset(all_records)
  local mp_vs_eib = select_moralpanic_vs_eib(all_records)

  local cost_weights = args.cost_weights or {
    fn_high_S = 5.0,
    fn_high_P = 5.0,
    miss_doom_heavy = 4.0,
    fp_low = 1.0,
  }

  local combos = cartesian_product(grid)
  local best = nil
  local best_id = nil

  local sweep_summary = {}
  local targeted_summary = {}

  for idx, theta in ipairs(combos) do
    local theta_name = theta_id(theta)

    -- Global evaluation on all gold records.
    local res_all = evaluate_theta_on_subset(theta, splits.all, cost_weights)
    local dom_res = evaluate_theta_across_domains(theta, splits, cost_weights)
    local conf = confusion_matrix_claimtype(select(2, run_classifier_on_records(splits.all)))

    -- Targeted analysis on disagreement and Moral Panic vs EIB.
    local targ_dis = nil
    if #disagreements > 0 then
      targ_dis = targeted_error_analysis(theta, disagreements)
    end
    local targ_mp_eib = nil
    if #mp_vs_eib > 0 then
      targ_mp_eib = targeted_error_analysis(theta, mp_vs_eib)
    end

    sweep_summary[theta_name] = {
      theta = theta,
      all = res_all,
      domains = dom_res,
      confusion = conf,
    }
    targeted_summary[theta_name] = {
      disagreements = targ_dis,
      moralpanic_vs_eib = targ_mp_eib,
    }

    -- Selection rule: prefer lower cost; break ties with higher macro-F1.
    local score_cost = res_all[1].cost
    local score_f1 = res_all[1].macroF1
    if not best or score_cost < best.cost or
      (math.abs(score_cost - best.cost) < 1e-6 and score_f1 > best.macroF1) then
      best = {
        theta = deepcopy(theta),
        cost = score_cost,
        macroF1 = score_f1,
        domains = dom_res,
      }
      best_id = theta_name
    end
  end

  -- Write summaries.
  local best_path = out_dir .. "/best_theta.json"
  local sweep_path = out_dir .. "/threshold_sweep_summary.json"
  local targ_path = out_dir .. "/threshold_targeted_summary.json"

  do
    local fh = assert(io.open(best_path, "w"))
    fh:write(json.encode({
      best_theta = best.theta,
      selector = "min_cost_then_max_macroF1",
      best_id = best_id,
      global_cost = best.cost,
      global_macroF1 = best.macroF1,
      domains = best.domains,
    }, {indent = true}))
    fh:close()
  end

  do
    local fh = assert(io.open(sweep_path, "w"))
    fh:write(json.encode(sweep_summary, {indent = false}))
    fh:close()
  end

  do
    local fh = assert(io.open(targ_path, "w"))
    fh:write(json.encode(targeted_summary, {indent = false}))
    fh:close()
  end

  return best
end

----------------------------------------------------------------------
-- 10. CLI entrypoint
--
-- Example:
--   lua -e 'require("src.gesp_threshold_sweep").run{
--            gold_path="data/corpus_gold.jsonl",
--            out_dir="output/threshold_sweep"
--          }'
----------------------------------------------------------------------

return ThresholdSweep
