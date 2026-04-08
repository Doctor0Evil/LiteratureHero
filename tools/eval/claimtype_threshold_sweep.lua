-- tools/eval/claimtype_threshold_sweep.lua
-- Claim-type + d/dD band threshold sweep with cost-sensitive, safety-first objective.
--
-- This module:
--   - Loads the gold corpus and baseline analyzer stack.
--   - Sweeps over (t_dom, t_all, t_doom, q_low, q_high) threshold grids.
--   - Uses the configured doom/agency decoder (0xIHNN) to produce d/dD.
--   - Computes cost-sensitive loss, macro-F1, confusion matrices, and domain metrics.
--   - Emits JSON, CSV, and Markdown reports for the best global thresholds and
--     for the entire sweep grid.
--
-- It is designed to be orchestrated by gesp_validation_harness.lua, but can also
-- be run standalone:
--   lua tools/eval/claimtype_threshold_sweep.lua

----------------------------------------------------------------------
-- 0. Requires and wiring
----------------------------------------------------------------------

local json_ok, cjson = pcall(require, "cjson")
local json = json_ok and cjson or nil

-- Adjust module names/paths to your repo layout.
local GoldCorpus = require("data.corpus_gold_v1")          -- exposes .records
local DiscourseAnalyzer = require("src.gesp_discourse_analyzer")
local ClaimClassifier = require("src.claim_classifier")    -- classify_claim(text, ctx)
local DoomDecoder = require("src.doomagencydecoder")       -- weighted d/dD using 0xIHNN config
local MetricsAndLoss = require("tools.eval.metrics_and_loss") -- L_cost, F1 routines, etc.

----------------------------------------------------------------------
-- 1. Config: sweep grids and safety weights
----------------------------------------------------------------------

local OUTPUT_DIR = "output"
local REPORT_DIR = "reports"
local SWEEP_ID   = os.date("claimtype_sweep_%Y%m%d_%H%M%S")

-- Core grids (edit if needed or make them read from a config file).
local CONFIG = {
  doom_decoder_hex = "0x0000",   -- default unweighted; can be overridden.

  -- Threshold grids
  t_dom_grid  = { 0.55, 0.60, 0.70 },      -- dominance for Single-Factor Doom
  t_all_grid  = { 0.40, 0.50, 0.60 },      -- "everything high" min-stress for EIB
  t_doom_grid = { 0.70, 0.80, 0.90 },      -- doom-saturation for d/dD

  -- dD quantiles (low/high bands for agency/mixed/doom). Same across G/E/S/P.
  dD_quantile_grid = {
    { q_low = 0.25, q_high = 0.75 },
    { q_low = 0.20, q_high = 0.80 },
    { q_low = 0.30, q_high = 0.70 }
  },

  -- Safety-first lambda weights for objective:
  lambda_cost  = 1.0,
  lambda_macro = 0.1,

  -- Domain degradation flags
  domain_degradation_max_delta_F1   = 0.10,
  domain_degradation_max_rel_cost   = 0.20
}

----------------------------------------------------------------------
-- 2. Utilities
----------------------------------------------------------------------

local function ensure_dir(path)
  os.execute(string.format("mkdir -p %s", path))
end

local function safediv(num, den)
  den = den or 0
  if den == 0 then return 0 end
  return num / den
end

-- Extract domain label from record (fiction/news/social/other).
local function get_domain(rec)
  local src = (rec.context_source or rec.context_domain or "other"):lower()
  if src:find("fiction") then return "fiction" end
  if src:find("news") then return "news" end
  if src:find("social") then return "social" end
  return "other"
end

----------------------------------------------------------------------
-- 3. d/dD band helpers (quantile-based)
----------------------------------------------------------------------

local function compute_quantiles(values, q_low, q_high)
  table.sort(values)
  local N = #values
  if N == 0 then
    return { low = q_low, mid = 0.5, high = q_high }
  end

  local function at_q(q)
    local pos = q * (N - 1) + 1
    local lo = math.floor(pos)
    local hi = math.ceil(pos)
    if lo == hi then
      return values[lo]
    else
      local w = pos - lo
      return values[lo] * (1 - w) + values[hi] * w
    end
  end

  local low  = at_q(q_low)
  local high = at_q(q_high)
  local mid  = at_q(0.5)

  return { low = low, mid = mid, high = high }
end

local function label_band_from_scalar(d_value, bands)
  if d_value == nil then return "mixed" end
  local low  = bands.low  or 0.33
  local high = bands.high or 0.66
  if d_value < low then
    return "agency-leaning"
  elseif d_value < high then
    return "mixed"
  else
    return "doom-leaning"  -- treat everything above high as doom-leaning/doom-saturated
  end
end

local function label_band_dD(dD_table, bands_common)
  local labels = {}
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local v = dD_table[dim] or 0
    labels[dim] = label_band_from_scalar(v, bands_common)
  end
  return labels
end

----------------------------------------------------------------------
-- 4. Claim-type metrics (macro-F1, confusion) using MetricsAndLoss
----------------------------------------------------------------------

local function compute_claimtype_metrics(y_true, y_pred)
  -- If MetricsAndLoss already exposes a macro-F1 routine, call it.
  -- Otherwise, fall back to a local implementation.
  if MetricsAndLoss.claimtype_metrics then
    return MetricsAndLoss.claimtype_metrics(y_true, y_pred)
  end

  -- Fallback: simple multiclass F1.
  local labels = {}
  local seen = {}
  for i = 1, #y_true do
    local t = y_true[i]
    local p = y_pred[i]
    if t and not seen[t] then seen[t] = true; labels[#labels+1] = t end
    if p and not seen[p] then seen[p] = true; labels[#labels+1] = p end
  end

  local counts = {}
  for _, lab in ipairs(labels) do
    counts[lab] = { TP = 0, FP = 0, FN = 0, TN = 0 }
  end

  for i = 1, #y_true do
    local t = y_true[i]
    local p = y_pred[i]
    for _, lab in ipairs(labels) do
      local c = counts[lab]
      if t == lab and p == lab then
        c.TP = c.TP + 1
      elseif t ~= lab and p == lab then
        c.FP = c.FP + 1
      elseif t == lab and p ~= lab then
        c.FN = c.FN + 1
      else
        c.TN = c.TN + 1
      end
    end
  end

  local macroP, macroR, macroF1 = 0, 0, 0
  local microTP, microFP, microFN = 0, 0, 0
  local per_type = {}

  for _, lab in ipairs(labels) do
    local c = counts[lab]
    local P = safediv(c.TP, (c.TP + c.FP))
    local R = safediv(c.TP, (c.TP + c.FN))
    local F1 = (P + R) > 0 and (2 * P * R / (P + R)) or 0

    per_type[lab] = { precision = P, recall = R, f1 = F1 }

    macroP = macroP + P
    macroR = macroR + R
    macroF1 = macroF1 + F1

    microTP = microTP + c.TP
    microFP = microFP + c.FP
    microFN = microFN + c.FN
  end

  local nL = #labels
  macroP = safediv(macroP, nL)
  macroR = safediv(macroR, nL)
  macroF1 = safediv(macroF1, nL)

  local microP = safediv(microTP, (microTP + microFP))
  local microR = safediv(microTP, (microTP + microFN))
  local microF1 = (microP + microR) > 0 and (2 * microP * microR / (microP + microR)) or 0

  return {
    labels = labels,
    per_type = per_type,
    macro = { precision = macroP, recall = macroR, f1 = macroF1 },
    micro = { precision = microP, recall = microR, f1 = microF1 },
    confusion_counts = counts
  }
end

----------------------------------------------------------------------
-- 5. Cost-sensitive loss wrapper
----------------------------------------------------------------------

local function compute_cost_loss(run_outputs)
  -- run_outputs: table per record with fields the harness needs.
  -- We delegate to MetricsAndLoss if available; otherwise a simple FN/FP S/P loss.
  if MetricsAndLoss.cost_weighted_loss then
    return MetricsAndLoss.cost_weighted_loss(run_outputs)
  end

  local cost = 0
  local w_miss_SP = 5
  local w_miss_doom = 4
  local w_fp_spurious = 1

  for _, row in ipairs(run_outputs) do
    local g_dD = row.gold_dD or {}
    local p_dD = row.pred_dD or {}
    local g_labels = row.gold_dD_labels or {}
    local p_labels = row.pred_dD_labels or {}

    for _, D in ipairs({ "S", "P" }) do
      local gv = g_dD[D] or 0
      local pv = p_dD[D] or 0
      local gL = g_labels[D]
      local pL = p_labels[D]

      local doom_sat = (gL == "doom-leaning" or gL == "doom-saturated" or gv >= 0.9)
      local pred_not_doom = not (pL == "doom-leaning" or pL == "doom-saturated" or pv >= 0.7)

      if doom_sat and pred_not_doom then
        cost = cost + w_miss_SP
        if gv >= 0.9 and pv < 0.7 then
          cost = cost + w_miss_doom
        end
      end

      local gold_not_doom = (gv < 0.7 and gL ~= "doom-leaning" and gL ~= "doom-saturated")
      local pred_doom = (pv >= 0.7 or pL == "doom-leaning" or pL == "doom-saturated")
      if gold_not_doom and pred_doom then
        cost = cost + w_fp_spurious
      end
    end
  end

  return cost
end

----------------------------------------------------------------------
-- 6. Core sweep: run one θ = (t_dom, t_all, t_doom, q_low, q_high)
----------------------------------------------------------------------

local function run_single_configuration(records, theta, gold_d_values)
  local t_dom, t_all, t_doom = theta.t_dom, theta.t_all, theta.t_doom
  local q_low, q_high = theta.q_low, theta.q_high

  -- Compute global dD bands from gold d values.
  local bands_common = compute_quantiles(gold_d_values, q_low, q_high)

  local y_true, y_pred = {}, {}
  local outputs = {}

  -- Per-domain metrics: fiction, news, social, other.
  local domain_true, domain_pred = {fiction={},news={},social={},other={}},
                                   {fiction={},news={},social={},other={}}

  for idx, rec in ipairs(records) do
    local text = rec.text or ""
    local gold_type = rec.claimtype or "unknown"
    local domain = get_domain(rec)

    -- Configure doom decoder with given hex (doom weights, negation, etc.).
    local decoder_opts = { config_hex = theta.doom_decoder_hex }
    local doom_res = DoomDecoder.analyzetext(text, decoder_opts) or {}

    local d_overall = doom_res.doverall or 0
    local d_perdim  = doom_res.dperdim or { G=0, E=0, S=0, P=0 }

    local d_labels = label_band_dD(d_perdim, bands_common)

    -- Context for claim classifier (thresholds + bands + doom scores).
    local ctx = {
      thresholds = {
        t_dom  = t_dom,
        t_all  = t_all,
        t_doom = t_doom
      },
      d_bands = bands_common,
      dD_bands = bands_common,
      doom_scores = {
        doverall = d_overall,
        dperdim  = d_perdim,
        labels   = d_labels
      },
      doom_decoder_hex = theta.doom_decoder_hex
    }

    local pred = ClaimClassifier.classifyclaim(text, ctx) or {}
    local pred_type = pred.claimtype or "unknown"

    y_true[idx] = gold_type
    y_pred[idx] = pred_type

    table.insert(domain_true[domain], gold_type)
    table.insert(domain_pred[domain], pred_type)

    local gold_dD = rec.dD and rec.dD.perdim or { G=0, E=0, S=0, P=0 }
    local gold_dD_labels = label_band_dD(gold_dD, bands_common)

    outputs[#outputs+1] = {
      gold_claimtype = gold_type,
      pred_claimtype = pred_type,
      gold_dD        = gold_dD,
      pred_dD        = d_perdim,
      gold_dD_labels = gold_dD_labels,
      pred_dD_labels = d_labels,
      domain         = domain,
      id             = rec.id or tostring(idx),
      is_disagree    = rec.disagreement_notes ~= nil,
      gold_A         = rec.annotator_a_claimtype,
      gold_B         = rec.annotator_b_claimtype
    }
  end

  -- Global claim-type metrics
  local m_claim = compute_claimtype_metrics(y_true, y_pred)
  local macroF1 = m_claim.macro.f1 or 0

  -- Cost-sensitive loss
  local L_cost = compute_cost_loss(outputs)

  -- Domain-specific macro-F1 for best θ analysis
  local domain_metrics = {}
  for _, dom in ipairs({"fiction","news","social","other"}) do
    if #domain_true[dom] > 0 then
      local dm = compute_claimtype_metrics(domain_true[dom], domain_pred[dom])
      domain_metrics[dom] = { macro_f1 = dm.macro.f1 or 0 }
    else
      domain_metrics[dom] = { macro_f1 = 0 }
    end
  end

  -- Moral Panic vs Everything-Is-Broken confusion counts
  local mp_to_eib, eib_to_mp = 0, 0
  for i = 1, #y_true do
    if y_true[i] == "Moral Panic" and y_pred[i] == "Everything-Is-Broken" then
      mp_to_eib = mp_to_eib + 1
    elseif y_true[i] == "Everything-Is-Broken" and y_pred[i] == "Moral Panic" then
      eib_to_mp = eib_to_mp + 1
    end
  end

  -- Annotator disagreement subset metrics
  local dis_true, dis_pred = {}, {}
  local align_A, align_B, align_neither = 0, 0, 0
  for _, row in ipairs(outputs) do
    if row.is_disagree then
      local t = row.gold_claimtype
      local p = row.pred_claimtype
      dis_true[#dis_true+1] = t
      dis_pred[#dis_pred+1] = p

      local A = row.gold_A
      local B = row.gold_B
      if A and p == A then
        align_A = align_A + 1
      elseif B and p == B then
        align_B = align_B + 1
      else
        align_neither = align_neither + 1
      end
    end
  end
  local disagree_metrics = nil
  if #dis_true > 0 then
    disagree_metrics = compute_claimtype_metrics(dis_true, dis_pred)
  end

  return {
    theta            = theta,
    outputs          = outputs,
    macroF1          = macroF1,
    L_cost           = L_cost,
    claim_metrics    = m_claim,
    domain_metrics   = domain_metrics,
    mp_to_eib        = mp_to_eib,
    eib_to_mp        = eib_to_mp,
    disagree_metrics = disagree_metrics,
    disagree_align   = { A = align_A, B = align_B, neither = align_neither }
  }
end

----------------------------------------------------------------------
-- 7. Sweep over grid and pick best θ
----------------------------------------------------------------------

local function collect_gold_d_values(records)
  local vals = {}
  for _, rec in ipairs(records) do
    if rec.dD and rec.dD.overall then
      table.insert(vals, rec.dD.overall)
    end
  end
  if #vals == 0 then table.insert(vals, 0.0) end
  return vals
end

local function run_sweep()
  ensure_dir(OUTPUT_DIR)
  ensure_dir(REPORT_DIR)

  local records = GoldCorpus.records or {}
  if #records == 0 then
    print("[claimtype_threshold_sweep] No gold records found; aborting.")
    return
  end

  print(string.format("[claimtype_threshold_sweep] Loaded %d gold records.", #records))

  local gold_d_values = collect_gold_d_values(records)
  local results = {}

  for _, t_dom in ipairs(CONFIG.t_dom_grid) do
    for _, t_all in ipairs(CONFIG.t_all_grid) do
      for _, t_doom in ipairs(CONFIG.t_doom_grid) do
        for _, qpair in ipairs(CONFIG.dD_quantile_grid) do
          local theta = {
            t_dom           = t_dom,
            t_all           = t_all,
            t_doom          = t_doom,
            q_low           = qpair.q_low,
            q_high          = qpair.q_high,
            doom_decoder_hex = CONFIG.doom_decoder_hex
          }

          local res = run_single_configuration(records, theta, gold_d_values)

          -- Safety-first objective
          local J = - CONFIG.lambda_cost * res.L_cost
                    + CONFIG.lambda_macro * res.macroF1

          res.J = J
          results[#results+1] = res

          print(string.format(
            "[θ] t_dom=%.2f t_all=%.2f t_doom=%.2f q=(%.2f,%.2f) | macroF1=%.3f L_cost=%.1f J=%.3f",
            t_dom, t_all, t_doom, qpair.q_low, qpair.q_high,
            res.macroF1, res.L_cost, J
          ))
        end
      end
    end
  end

  -- Select best J
  local best_idx, best_J = nil, nil
  for i, r in ipairs(results) do
    if not best_J or r.J > best_J then
      best_J = r.J
      best_idx = i
    end
  end

  if not best_idx then
    print("[claimtype_threshold_sweep] No best configuration found.")
    return
  end

  local best = results[best_idx]
  print("[claimtype_threshold_sweep] Selected global best θ*:")
  print(string.format(
    "  t_dom=%.2f t_all=%.2f t_doom=%.2f q=(%.2f,%.2f) | macroF1=%.3f L_cost=%.1f J=%.3f",
    best.theta.t_dom, best.theta.t_all, best.theta.t_doom,
    best.theta.q_low, best.theta.q_high,
    best.macroF1, best.L_cost, best.J
  ))

  --------------------------------------------------------------------
  -- 8. Domain degradation checks for θ*
  --------------------------------------------------------------------

  local best_global_macroF1 = best.macroF1
  local best_global_L_cost  = best.L_cost

  local domain_flags = {}
  for dom, dm in pairs(best.domain_metrics or {}) do
    local dF1  = best_global_macroF1 - (dm.macro_f1 or 0)
    local relL = safediv((dm.L_cost or best_global_L_cost) - best_global_L_cost, best_global_L_cost)

    local flagF1  = (dF1  > CONFIG.domain_degradation_max_delta_F1)
    local flagCost = (relL > CONFIG.domain_degradation_max_rel_cost)

    domain_flags[dom] = {
      delta_macroF1 = dF1,
      rel_cost_increase = relL,
      flag_F1  = flagF1,
      flag_cost = flagCost
    }
  end

  --------------------------------------------------------------------
  -- 9. Write JSON config and CSV grid
  --------------------------------------------------------------------

  local json_path = string.format("%s/%s_best.json", OUTPUT_DIR, SWEEP_ID)
  if json then
    local payload = {
      sweep_id     = SWEEP_ID,
      config       = CONFIG,
      best_theta   = best.theta,
      best_metrics = {
        macroF1  = best.macroF1,
        L_cost   = best.L_cost,
        J        = best.J,
        mp_to_eib = best.mp_to_eib,
        eib_to_mp = best.eib_to_mp,
        disagree_align = best.disagree_align
      },
      domain_flags = domain_flags
    }
    local fh = io.open(json_path, "w")
    if fh then
      fh:write(json.encode(payload))
      fh:close()
      print("[claimtype_threshold_sweep] Wrote best config JSON to " .. json_path)
    end
  end

  local csv_path = string.format("%s/%s_grid.csv", OUTPUT_DIR, SWEEP_ID)
  local fh_csv = io.open(csv_path, "w")
  if fh_csv then
    fh_csv:write("t_dom,t_all,t_doom,q_low,q_high,macroF1,L_cost,J,mp_to_eib,eib_to_mp\n")
    for _, r in ipairs(results) do
      fh_csv:write(string.format(
        "%.3f,%.3f,%.3f,%.3f,%.3f,%.4f,%.2f,%.4f,%d,%d\n",
        r.theta.t_dom, r.theta.t_all, r.theta.t_doom,
        r.theta.q_low, r.theta.q_high,
        r.macroF1, r.L_cost, r.J,
        r.mp_to_eib or 0, r.eib_to_mp or 0
      ))
    end
    fh_csv:close()
    print("[claimtype_threshold_sweep] Wrote sweep grid CSV to " .. csv_path)
  end

  --------------------------------------------------------------------
  -- 10. Markdown summary for GitHub
  --------------------------------------------------------------------

  local md_path = string.format("%s/%s_summary.md", REPORT_DIR, SWEEP_ID)
  local fh_md = io.open(md_path, "w")
  if fh_md then
    fh_md:write("# Claim-Type Threshold Sweep Summary\n\n")
    fh_md:write(string.format("- Sweep ID: `%s`\n", SWEEP_ID))
    fh_md:write("- Objective: maximize `J = -lambda_cost * L_cost + lambda_macro * F1_macro` with safety-first lambdas.\n\n")

    fh_md:write("## Best Global Thresholds\n\n")
    fh_md:write(string.format(
      "- `t_dom` (dominance): **%.2f**\n- `t_all` (everything-high): **%.2f**\n- `t_doom` (doom-saturation): **%.2f**\n- `q_low`, `q_high` (dD quantiles): **%.2f**, **%.2f**\n\n",
      best.theta.t_dom, best.theta.t_all, best.theta.t_doom,
      best.theta.q_low, best.theta.q_high
    ))
    fh_md:write(string.format(
      "- Global macro-F1 (claim types): **%.3f**\n- Global cost-sensitive loss `L_cost`: **%.1f**\n- Combined objective `J`: **%.3f**\n\n",
      best.macroF1, best.L_cost, best.J
    ))

    fh_md:write("### Moral Panic vs Everything-Is-Broken Confusions\n\n")
    fh_md:write(string.format(
      "- Moral Panic → Everything-Is-Broken: **%d**\n- Everything-Is-Broken → Moral Panic: **%d**\n\n",
      best.mp_to_eib or 0, best.eib_to_mp or 0
    ))

    fh_md:write("### Annotator Disagreement Slice\n\n")
    if best.disagree_metrics then
      fh_md:write(string.format(
        "- Disagreement macro-F1: **%.3f**\n- Align with annotator A: **%d**\n- Align with annotator B: **%d**\n- Align with neither: **%d**\n\n",
        best.disagree_metrics.macro.f1 or 0,
        best.disagree_align.A or 0,
        best.disagree_align.B or 0,
        best.disagree_align.neither or 0
      ))
    else
      fh_md:write("- No disagreement items detected in this run.\n\n")
    end

    fh_md:write("## Domain Breakdown and Degradation Flags\n\n")
    for _, dom in ipairs({"fiction","news","social","other"}) do
      local dm   = best.domain_metrics[dom] or {}
      local flag = domain_flags[dom] or {}
      fh_md:write(string.format("### %s\n\n", dom:gsub("^%l", string.upper)))
      fh_md:write(string.format(
        "- Domain macro-F1: **%.3f**\n- Δ macro-F1 vs global: **%.3f**\n- Relative cost increase vs global: **%.3f**\n",
        dm.macro_f1 or 0,
        flag.delta_macroF1 or 0,
        flag.rel_cost_increase or 0
      ))
      if flag.flag_F1 or flag.flag_cost then
        fh_md:write("- **Degradation flagged**: consider domain-specific threshold tuning.\n\n")
      else
        fh_md:write("- No severe degradation flagged under configured thresholds.\n\n")
      end
    end

    fh_md:write("## Notes\n\n")
    fh_md:write("- Lambda weights used: ")
    fh_md:write(string.format("`lambda_cost=%.2f`, `lambda_macro=%.2f`.\n\n", CONFIG.lambda_cost, CONFIG.lambda_macro))
    fh_md:write("- Decoder configuration hex: `" .. (CONFIG.doom_decoder_hex or "0x0000") .. "`.\n")
    fh_md:write("- Full sweep grid and per-run metrics are available in the CSV artifact.\n")

    fh_md:close()
    print("[claimtype_threshold_sweep] Wrote Markdown summary to " .. md_path)
  end
end

----------------------------------------------------------------------
-- 11. Entry point
----------------------------------------------------------------------

run_sweep()
