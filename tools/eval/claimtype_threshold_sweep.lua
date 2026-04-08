-- tools/eval/claimtype_threshold_sweep.lua
-- Threshold sweep for claim-type and d/dD band calibration on the gold corpus.
--
-- Responsibilities
-- - Load gold corpus records (claimtype, d, dDgold, etc.).
-- - Iterate over a grid of threshold configurations θ:
--     * d/dD band quantiles (global or per-dimension).
--     * Claim-type rule thresholds (e.g., Single-Factor Doom, Everything-Is-Broken).
-- - For each θ, run the claim classifier and compute:
--     * Per-type precision/recall/F1.
--     * Macro-F1 and micro-F1 over claim types.
--     * d/dD MAE (overall and per dimension).
--     * Cost-sensitive loss focused on high S/P stress and doom-saturated mislabels.
-- - Write CSV/JSON summaries to output/, including θ* (best-performing settings).
--
-- This script is designed to be invoked via:
--   lua tools/eval/claimtype_threshold_sweep.lua

local json_ok, cjson = pcall(require, "cjson")
local json = json_ok and cjson or nil

-- Adjust require paths as needed for your repo layout.
local GoldCorpus = require("data.corpus_gold_v1")       -- expects corpus.records
local ClaimClassifier = require("src.claim_classifier") -- classify_claim(text, ctx)
local DoomAgency = require("src.doomagencydecoder")     -- for d, dD if needed
local MetricsUtil = {}                                  -- helper metrics (local)

----------------------------------------------------------------------
-- 0. Config and utility helpers
----------------------------------------------------------------------

local OUTPUT_DIR = "output"
local SWEEP_ID   = os.date("claimtype_sweep_%Y%m%d_%H%M%S")

-- Helper: ensure output directory exists (best-effort).
local function ensure_output_dir()
  local ok = os.execute(string.format("mkdir -p %s", OUTPUT_DIR))
  return ok
end

local function safediv(num, den)
  den = den or 0
  if den == 0 then return 0 end
  return num / den
end

----------------------------------------------------------------------
-- 1. Metric helper functions (per-type F1, macro/micro F1, confusion)
----------------------------------------------------------------------

-- Compute per-class precision, recall, F1, and confusion counts.
-- y_true, y_pred: arrays of strings (claimtype labels).
function MetricsUtil.claimtype_metrics(y_true, y_pred)
  local labels = {}
  local label_index = {}
  for i = 1, #y_true do
    local t = y_true[i]
    local p = y_pred[i]
    if t and not label_index[t] then
      label_index[t] = true
      labels[#labels + 1] = t
    end
    if p and not label_index[p] then
      label_index[p] = true
      labels[#labels + 1] = p
    end
  end

  local counts = {}
  for _, lab in ipairs(labels) do
    counts[lab] = {
      TP = 0, FP = 0, FN = 0, TN = 0
    }
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

  local per_type = {}
  local macroP, macroR, macroF1 = 0, 0, 0
  local microTP, microFP, microFN = 0, 0, 0

  for _, lab in ipairs(labels) do
    local c = counts[lab]
    local P = safediv(c.TP, (c.TP + c.FP))
    local R = safediv(c.TP, (c.TP + c.FN))
    local F1 = (P + R) > 0 and (2 * P * R / (P + R)) or 0

    per_type[lab] = {
      precision = P,
      recall = R,
      f1 = F1,
      TP = c.TP,
      FP = c.FP,
      FN = c.FN,
      TN = c.TN
    }

    macroP = macroP + P
    macroR = macroR + R
    macroF1 = macroF1 + F1

    microTP = microTP + c.TP
    microFP = microFP + c.FP
    microFN = microFN + c.FN
  end

  local n_labels = #labels
  macroP = safediv(macroP, n_labels)
  macroR = safediv(macroR, n_labels)
  macroF1 = safediv(macroF1, n_labels)

  local microP = safediv(microTP, (microTP + microFP))
  local microR = safediv(microTP, (microTP + microFN))
  local microF1 = (microP + microR) > 0 and (2 * microP * microR / (microP + microR)) or 0

  return {
    labels = labels,
    per_type = per_type,
    macro = { precision = macroP, recall = macroR, f1 = macroF1 },
    micro = { precision = microP, recall = microR, f1 = microF1 }
  }
end

-- Compute MAE for d and dD given arrays of predicted and gold values.
function MetricsUtil.d_mae(pred, gold)
  local N = #pred
  local sum = 0
  for i = 1, N do
    local dp = pred[i] or 0
    local dg = gold[i] or 0
    sum = sum + math.abs(dp - dg)
  end
  return safediv(sum, N)
end

function MetricsUtil.dD_mae(predD, goldD)
  -- predD and goldD are arrays of tables {G=..,E=..,S=..,P=..}
  local N = #predD
  local sumG, sumE, sumS, sumP = 0, 0, 0, 0
  for i = 1, N do
    local pp = predD[i] or {}
    local gg = goldD[i] or {}
    sumG = sumG + math.abs((pp.G or 0) - (gg.G or 0))
    sumE = sumE + math.abs((pp.E or 0) - (gg.E or 0))
    sumS = sumS + math.abs((pp.S or 0) - (gg.S or 0))
    sumP = sumP + math.abs((pp.P or 0) - (gg.P or 0))
  end
  return {
    G = safediv(sumG, N),
    E = safediv(sumE, N),
    S = safediv(sumS, N),
    P = safediv(sumP, N)
  }
end

-- Cost-sensitive doom error: focus on S/P doom-saturated misses and over-warnings.
-- gold_dD_labels, pred_dD_labels: arrays of per-dim qualitative labels (strings).
-- gold_dD_numeric, pred_dD_numeric: arrays of numeric dD per dimension.
function MetricsUtil.cost_sensitive_doom_loss(gold_dD_labels, pred_dD_labels, gold_dD_numeric, pred_dD_numeric, weights)
  weights = weights or {
    miss_doom_S = 5,
    miss_doom_P = 5,
    fp_doom_S = 1,
    fp_doom_P = 1,
    underest_high_d = 4
  }

  local dims = { "S", "P" }
  local total_cost = 0

  for i = 1, #gold_dD_labels do
    local gL = gold_dD_labels[i] or {}
    local pL = pred_dD_labels[i] or {}
    local gN = gold_dD_numeric[i] or {}
    local pN = pred_dD_numeric[i] or {}

    for _, D in ipairs(dims) do
      local gBand = gL[D]
      local pBand = pL[D]
      local gVal = gN[D] or 0
      local pVal = pN[D] or 0

      local doom_sat = (gBand == "doom-saturated")
      local pred_not_doom = (pBand ~= "doom-leaning" and pBand ~= "doom-saturated")

      -- Missed doom-saturated case
      if doom_sat and pred_not_doom then
        if D == "S" then
          total_cost = total_cost + weights.miss_doom_S
        elseif D == "P" then
          total_cost = total_cost + weights.miss_doom_P
        end
      end

      -- Spurious doom labeling (low-cost)
      local gold_not_doom = (gBand ~= "doom-leaning" and gBand ~= "doom-saturated")
      local pred_doom = (pBand == "doom-leaning" or pBand == "doom-saturated")
      if gold_not_doom and pred_doom then
        if D == "S" then
          total_cost = total_cost + weights.fp_doom_S
        elseif D == "P" then
          total_cost = total_cost + weights.fp_doom_P
        end
      end

      -- High numeric underestimation near 1.0
      if gVal >= 0.9 and pVal < 0.7 then
        total_cost = total_cost + weights.underest_high_d
      end
    end
  end

  return total_cost
end

----------------------------------------------------------------------
-- 2. Band labeling helpers (for d and dD)
----------------------------------------------------------------------

local function label_band_d(d_value, bands)
  if d_value == nil then return "mixed" end
  if d_value < bands.q1 then
    return "agency-leaning"
  elseif d_value < bands.q2 then
    return "mixed"
  elseif d_value < bands.q3 then
    return "doom-leaning"
  else
    return "doom-saturated"
  end
end

local function label_band_dD(dD_table, bandsD)
  local labels = {}
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local v = dD_table[dim] or 0
    local b = bandsD[dim] or bandsD.global
    labels[dim] = label_band_d(v, b)
  end
  return labels
end

----------------------------------------------------------------------
-- 3. Threshold configuration grid
----------------------------------------------------------------------

-- Candidate quantile triples for global d bands.
local BAND_QUANTILE_GRID = {
  { q1 = 0.25, q2 = 0.5, q3 = 0.75 },
  { q1 = 0.20, q2 = 0.5, q3 = 0.80 },
  { q1 = 0.30, q2 = 0.5, q3 = 0.70 }
}

-- Simple claim-type threshold grid (example; adjust as needed).
-- Each entry can encode:
--   sf_max_dim_min   : min dominant sD for Single-Factor Doom
--   eib_high_dims_min: min count of high-stress dims for Everything-Is-Broken
local CLAIM_THRESHOLD_GRID = {
  { sf_max_dim_min = 0.6, eib_high_dims_min = 3 },
  { sf_max_dim_min = 0.7, eib_high_dims_min = 3 },
  { sf_max_dim_min = 0.6, eib_high_dims_min = 2 }
}

-- Helper: quantile computation on an array of numbers [0,1].
local function compute_quantiles(values, q1, q2, q3)
  table.sort(values)
  local N = #values
  if N == 0 then
    return { q1 = 0.25, q2 = 0.5, q3 = 0.75 }
  end

  local function at_quantile(q)
    local pos = q * (N - 1) + 1
    local low = math.floor(pos)
    local high = math.ceil(pos)
    if low == high then
      return values[low]
    else
      local w = pos - low
      return values[low] * (1 - w) + values[high] * w
    end
  end

  return {
    q1 = at_quantile(q1),
    q2 = at_quantile(q2),
    q3 = at_quantile(q3)
  }
end

----------------------------------------------------------------------
-- 4. Running the sweep over θ
----------------------------------------------------------------------

-- Extract gold d and dD from gold corpus.
local function collect_gold_d_values(records)
  local global_d = {}
  local per_dim_d = { G = {}, E = {}, S = {}, P = {} }

  for _, rec in ipairs(records) do
    if rec.dD and rec.dD.overall then
      table.insert(global_d, rec.dD.overall)
    end
    if rec.dD and rec.dD.perdim then
      for _, dim in ipairs({ "G", "E", "S", "P" }) do
        local v = rec.dD.perdim[dim]
        if v ~= nil then
          table.insert(per_dim_d[dim], v)
        end
      end
    end
  end

  return global_d, per_dim_d
end

-- High-level sweep runner
local function run_sweep()
  ensure_output_dir()

  local records = GoldCorpus.records or {}
  local N = #records
  if N == 0 then
    print("No gold records found in GoldCorpus.records; aborting sweep.")
    return
  end

  print(string.format("[claimtype_threshold_sweep] Loaded %d gold records.", N))

  local global_d, per_dim_d = collect_gold_d_values(records)

  local sweep_results = {}

  -- Iterate over band and claim threshold settings.
  for _, band_q in ipairs(BAND_QUANTILE_GRID) do
    -- Compute global bands from gold d.
    local global_bands = compute_quantiles(global_d, band_q.q1, band_q.q2, band_q.q3)

    -- Per-dimension bands: for simplicity, use same quantiles but per-dim data.
    local bands_per_dim = {}
    for _, dim in ipairs({ "G", "E", "S", "P" }) do
      bands_per_dim[dim] = compute_quantiles(per_dim_d[dim], band_q.q1, band_q.q2, band_q.q3)
    end

    for _, claim_th in ipairs(CLAIM_THRESHOLD_GRID) do
      local y_true = {}
      local y_pred = {}

      local pred_d_overall = {}
      local pred_d_perdim = {}
      local gold_d_overall = {}
      local gold_d_perdim = {}
      local gold_d_labels_perdim = {}
      local pred_d_labels_perdim = {}

      -- Run classifier on all records under current θ.
      for idx, rec in ipairs(records) do
        local text = rec.text or ""
        local gold_type = rec.claimtype or "unknown"

        -- Use gold d/dD numeric if present as "true"; classifier d/dD as "pred".
        local gold_d_val = rec.dD and rec.dD.overall or 0
        local gold_dD_val = rec.dD and rec.dD.perdim or { G = 0, E = 0, S = 0, P = 0 }

        gold_d_overall[idx] = gold_d_val
        gold_d_perdim[idx] = gold_dD_val
        gold_d_labels_perdim[idx] = label_band_dD(
          gold_dD_val,
          {
            G = bands_per_dim.G,
            E = bands_per_dim.E,
            S = bands_per_dim.S,
            P = bands_per_dim.P,
            global = global_bands
          }
        )

        -- Build a context/opts table to pass thresholds into the classifier.
        local ctx = {
          thresholds = {
            -- d/dD band bands used by classifier if it needs them.
            d_bands_global = global_bands,
            d_bands_perdim = bands_per_dim,
            -- Claim-type thresholds.
            sf_max_dim_min = claim_th.sf_max_dim_min,
            eib_high_dims_min = claim_th.eib_high_dims_min
          }
        }

        local result = ClaimClassifier.classifyclaim(text, ctx)
        local pred_type = result.claimtype or "unknown"
        y_true[idx] = gold_type
        y_pred[idx] = pred_type

        -- Obtain classifier's d and dD (if available).
        local pred_d_val = result.doverall or gold_d_val
        local pred_dD_val = result.dperdim or gold_dD_val

        pred_d_overall[idx] = pred_d_val
        pred_d_perdim[idx] = pred_dD_val
        pred_d_labels_perdim[idx] = label_band_dD(
          pred_dD_val,
          {
            G = bands_per_dim.G,
            E = bands_per_dim.E,
            S = bands_per_dim.S,
            P = bands_per_dim.P,
            global = global_bands
          }
        )
      end

      -- Compute metrics for this configuration.
      local m_claim = MetricsUtil.claimtype_metrics(y_true, y_pred)
      local mae_d = MetricsUtil.d_mae(pred_d_overall, gold_d_overall)
      local mae_dD = MetricsUtil.dD_mae(pred_d_perdim, gold_d_perdim)
      local doom_loss = MetricsUtil.cost_sensitive_doom_loss(
        gold_d_labels_perdim,
        pred_d_labels_perdim,
        gold_d_perdim,
        pred_d_perdim,
        nil
      )

      local entry = {
        band_quantiles = band_q,
        claim_thresholds = claim_th,
        metrics = {
          claimtype_macro_f1 = m_claim.macro.f1,
          claimtype_micro_f1 = m_claim.micro.f1,
          mae_d = mae_d,
          mae_dD = mae_dD,
          doom_loss = doom_loss
        }
      }

      sweep_results[#sweep_results + 1] = entry

      print(string.format(
        "[θ] bands=(%.2f,%.2f,%.2f) sf>=%.2f eib_dims>=%d | macro F1=%.3f, doom_loss=%.1f",
        band_q.q1, band_q.q2, band_q.q3,
        claim_th.sf_max_dim_min, claim_th.eib_high_dims_min,
        m_claim.macro.f1, doom_loss
      ))
    end
  end

  -- Select θ* by composite objective: low doom_loss, low mae_dD, high macro-F1.
  local best_idx = nil
  local best_score = nil
  for i, e in ipairs(sweep_results) do
    local f1 = e.metrics.claimtype_macro_f1 or 0
    local md = e.metrics.mae_dD or {}
    local doom_loss = e.metrics.doom_loss or 0
    local mae_S = md.S or 0
    local mae_P = md.P or 0

    -- Example objective (tune as needed):
    -- penalize doom_loss, penalize S/P MAE, reward F1.
    local score = - doom_loss - 10 * (mae_S + mae_P) + 100 * f1

    if best_score == nil or score > best_score then
      best_score = score
      best_idx = i
    end
  end

  local best = best_idx and sweep_results[best_idx] or nil
  if best then
    print("[claimtype_threshold_sweep] Selected θ*:")
    print(string.format(
      "  bands=(%.2f,%.2f,%.2f) sf>=%.2f eib_dims>=%d | macro F1=%.3f, doom_loss=%.1f",
      best.band_quantiles.q1, best.band_quantiles.q2, best.band_quantiles.q3,
      best.claim_thresholds.sf_max_dim_min, best.claim_thresholds.eib_high_dims_min,
      best.metrics.claimtype_macro_f1, best.metrics.doom_loss
    ))
  else
    print("[claimtype_threshold_sweep] No best configuration found (check inputs).")
  end

  -- Write JSON summary (if cjson available) and CSV.
  local json_path = string.format("%s/%s.json", OUTPUT_DIR, SWEEP_ID)
  local csv_path = string.format("%s/%s.csv", OUTPUT_DIR, SWEEP_ID)

  if json and best then
    local payload = {
      sweep_id = SWEEP_ID,
      results = sweep_results,
      best = best
    }
    local fh = io.open(json_path, "w")
    if fh then
      fh:write(json.encode(payload))
      fh:close()
      print("[claimtype_threshold_sweep] Wrote JSON summary to " .. json_path)
    end
  end

  local fh_csv = io.open(csv_path, "w")
  if fh_csv then
    fh_csv:write("q1,q2,q3,sf_max_dim_min,eib_high_dims_min,macro_f1,micro_f1,mae_d,mae_dG,mae_dE,mae_dS,mae_dP,doom_loss\n")
    for _, e in ipairs(sweep_results) do
      local bq = e.band_quantiles
      local ct = e.claim_thresholds
      local m = e.metrics
      local mae_dD = m.mae_dD or {}
      fh_csv:write(string.format(
        "%.2f,%.2f,%.2f,%.2f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.1f\n",
        bq.q1, bq.q2, bq.q3,
        ct.sf_max_dim_min, ct.eib_high_dims_min,
        m.claimtype_macro_f1 or 0,
        m.claimtype_micro_f1 or 0,
        m.mae_d or 0,
        mae_dD.G or 0, mae_dD.E or 0, mae_dD.S or 0, mae_dD.P or 0,
        m.doom_loss or 0
      ))
    end
    fh_csv:close()
    print("[claimtype_threshold_sweep] Wrote CSV summary to " .. csv_path)
  end
end

----------------------------------------------------------------------
-- 5. Entry point
----------------------------------------------------------------------

run_sweep()
