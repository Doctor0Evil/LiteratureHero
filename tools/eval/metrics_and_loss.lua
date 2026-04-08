-- tools/eval/metrics_and_loss.lua
-- Metric computation and cost-sensitive loss for the GESP Discourse Toolkit.
--
-- Responsibilities:
--   - Per-dimension MAE on s_D (claimed) and distortion D_D.
--   - MAE on dD overall and per dimension.
--   - Precision/Recall/F1 for high-stress vs not-high-stress per dimension.
--   - Macro F1 over claim types (secondary).
--   - Cost-sensitive loss that penalizes:
--       * FN on high Social/Political stress.
--       * Mislabeling doom-saturated discourse as non-doom.
--
-- Expected integration:
--   - Called from src/gesp_validation_harness.lua.
--   - Receives arrays of gold records and system outputs.

local M = {}

----------------------------------------------------------------------
-- 0. Utilities
----------------------------------------------------------------------

local function safediv(num, den)
  if den == 0 then return 0 end
  return num / den
end

local function abs(x)
  if x < 0 then return -x else return x end
end

local function new_dim_table(init)
  return { G = init or 0, E = init or 0, S = init or 0, P = init or 0 }
end

----------------------------------------------------------------------
-- 1. MAE computation
----------------------------------------------------------------------

-- inputs:
--   gold   : array of records with fields:
--              s_claimed = {G,E,S,P}
--              D_gold    = {G,E,S,P}   (optional; can be computed upstream)
--              dD_gold   = number
--              dD_dim_gold = {G,E,S,P} (optional)
--   sys    : array of records with same length as gold, fields:
--              s_pred    = {G,E,S,P}
--              D_pred    = {G,E,S,P}
--              dD_pred   = number
--              dD_dim_pred = {G,E,S,P}
function M.compute_mae(gold, sys)
  local n = #gold
  local mae_s = new_dim_table(0)
  local mae_D = new_dim_table(0)
  local mae_dD_dim = new_dim_table(0)
  local mae_dD_overall = 0

  for i = 1, n do
    local g = gold[i]
    local p = sys[i]

    local gs = g.s_claimed or new_dim_table(0)
    local ps = p.s_pred    or new_dim_table(0)

    local gD = g.D_gold or new_dim_table(0)
    local pD = p.D_pred or new_dim_table(0)

    local gdD_dim = g.dD_dim_gold or new_dim_table(0)
    local pdD_dim = p.dD_dim_pred or new_dim_table(0)

    local gdD = g.dD_gold or 0
    local pdD = p.dD_pred or 0

    for _, dim in ipairs({ "G", "E", "S", "P" }) do
      mae_s[dim] = mae_s[dim] + abs((gs[dim] or 0) - (ps[dim] or 0))
      mae_D[dim] = mae_D[dim] + abs((gD[dim] or 0) - (pD[dim] or 0))
      mae_dD_dim[dim] = mae_dD_dim[dim] + abs((gdD_dim[dim] or 0) - (pdD_dim[dim] or 0))
    end

    mae_dD_overall = mae_dD_overall + abs(gdD - pdD)
  end

  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    mae_s[dim]      = mae_s[dim]      / n
    mae_D[dim]      = mae_D[dim]      / n
    mae_dD_dim[dim] = mae_dD_dim[dim] / n
  end
  mae_dD_overall = mae_dD_overall / n

  return {
    mae_s = mae_s,
    mae_D = mae_D,
    mae_dD_dim = mae_dD_dim,
    mae_dD_overall = mae_dD_overall
  }
end

----------------------------------------------------------------------
-- 2. High-stress classification metrics per dimension
----------------------------------------------------------------------

-- High-stress label:
--   gold_high[D] = (s_claimed[D] >= tau_D)
--   pred_high[D] = (s_pred[D]    >= tau_D)
-- where tau_D are quantile-based thresholds derived from gold distribution.
--
-- inputs:
--   gold    : array, with s_claimed.
--   sys     : array, with s_pred.
--   tau     : {G=...,E=...,S=...,P=...} thresholds for "high" stress.
-- returns:
--   metrics_per_dim[dim] = { precision, recall, f1, tp, fp, fn, tn }

local function binarize_high(s, tau)
  local labels = {}
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    labels[dim] = (s[dim] or 0) >= (tau[dim] or 0.5)
  end
  return labels
end

function M.compute_high_stress_metrics(gold, sys, tau)
  local metrics = {}
  local counts = {}
  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    counts[dim] = { tp = 0, fp = 0, fn = 0, tn = 0 }
  end

  local n = #gold
  for i = 1, n do
    local gs = gold[i].s_claimed or new_dim_table(0)
    local ps = sys[i].s_pred     or new_dim_table(0)

    local g_hi = binarize_high(gs, tau)
    local p_hi = binarize_high(ps, tau)

    for _, dim in ipairs({ "G", "E", "S", "P" }) do
      local gh = g_hi[dim]
      local ph = p_hi[dim]
      local c = counts[dim]

      if gh and ph then
        c.tp = c.tp + 1
      elseif (not gh) and ph then
        c.fp = c.fp + 1
      elseif gh and (not ph) then
        c.fn = c.fn + 1
      else
        c.tn = c.tn + 1
      end
    end
  end

  for _, dim in ipairs({ "G", "E", "S", "P" }) do
    local c = counts[dim]
    local precision = safediv(c.tp, (c.tp + c.fp))
    local recall    = safediv(c.tp, (c.tp + c.fn))
    local f1 = 0
    if precision + recall > 0 then
      f1 = 2 * precision * recall / (precision + recall)
    end
    metrics[dim] = {
      precision = precision,
      recall = recall,
      f1 = f1,
      tp = c.tp,
      fp = c.fp,
      fn = c.fn,
      tn = c.tn
    }
  end

  return metrics
end

----------------------------------------------------------------------
-- 3. Claim-type macro F1 (secondary metric)
----------------------------------------------------------------------

-- inputs:
--   gold : array with claim_type (string).
--   sys  : array with claim_type_pred (string).
-- returns:
--   macro_f1 : number
--   per_type : table[type] = {precision, recall, f1, tp, fp, fn}

function M.compute_claimtype_macro_f1(gold, sys)
  local labels = {}
  for i = 1, #gold do
    labels[gold[i].claim_type] = true
    labels[sys[i].claim_type_pred] = true
  end

  local types = {}
  for t, _ in pairs(labels) do
    table.insert(types, t)
  end

  local stats = {}
  for _, t in ipairs(types) do
    stats[t] = { tp = 0, fp = 0, fn = 0 }
  end

  for i = 1, #gold do
    local gt = gold[i].claim_type
    local pt = sys[i].claim_type_pred
    for _, t in ipairs(types) do
      local s = stats[t]
      if gt == t and pt == t then
        s.tp = s.tp + 1
      elseif gt ~= t and pt == t then
        s.fp = s.fp + 1
      elseif gt == t and pt ~= t then
        s.fn = s.fn + 1
      end
    end
  end

  local sum_f1 = 0
  local n_types = #types
  local per_type = {}

  for _, t in ipairs(types) do
    local s = stats[t]
    local precision = safediv(s.tp, (s.tp + s.fp))
    local recall    = safediv(s.tp, (s.tp + s.fn))
    local f1 = 0
    if precision + recall > 0 then
      f1 = 2 * precision * recall / (precision + recall)
    end
    per_type[t] = {
      precision = precision,
      recall = recall,
      f1 = f1,
      tp = s.tp,
      fp = s.fp,
      fn = s.fn
    }
    sum_f1 = sum_f1 + f1
  end

  local macro_f1 = safediv(sum_f1, n_types)
  return macro_f1, per_type
end

----------------------------------------------------------------------
-- 4. Cost-sensitive loss
----------------------------------------------------------------------

-- Cost model:
--   - High cost for:
--       * FN in high Social or Political stress (ground truth high, predicted low).
--       * Mislabeling doom-saturated discourse (gold dD near 1) as non-doom.
--   - Lower cost for:
--       * FP in low-stress contexts.
--
-- inputs:
--   gold : array with fields:
--            s_claimed, dD_gold, dD_label_gold (optional band: agency/mixed/doom)
--   sys  : array with fields:
--            s_pred, dD_pred, dD_label_pred
--   tau  : high-stress thresholds per dimension.
--   cfg  : optional table with weights:
--            cfg.cost_FN_high_S
--            cfg.cost_FN_high_P
--            cfg.cost_miss_doom
--            cfg.cost_FP_low
--
-- returns:
--   loss_total
--   breakdown = { FN_high_S = ..., FN_high_P = ..., miss_doom = ..., FP_low = ... }

function M.compute_cost_sensitive_loss(gold, sys, tau, cfg)
  cfg = cfg or {}
  local w_FN_S   = cfg.cost_FN_high_S   or 5.0
  local w_FN_P   = cfg.cost_FN_high_P   or 5.0
  local w_miss_d = cfg.cost_miss_doom   or 4.0
  local w_FP_low = cfg.cost_FP_low      or 1.0

  local loss = 0.0
  local breakdown = {
    FN_high_S = 0.0,
    FN_high_P = 0.0,
    miss_doom = 0.0,
    FP_low    = 0.0
  }

  local n = #gold
  for i = 1, n do
    local g = gold[i]
    local p = sys[i]

    local gs = g.s_claimed or new_dim_table(0)
    local ps = p.s_pred    or new_dim_table(0)

    local g_hi = binarize_high(gs, tau)
    local p_hi = binarize_high(ps, tau)

    if g_hi.S and not p_hi.S then
      loss = loss + w_FN_S
      breakdown.FN_high_S = breakdown.FN_high_S + w_FN_S
    end

    if g_hi.P and not p_hi.P then
      loss = loss + w_FN_P
      breakdown.FN_high_P = breakdown.FN_high_P + w_FN_P
    end

    local gdD   = g.dD_gold or 0
    local pdD   = p.dD_pred or 0
    local gband = g.dD_label_gold or "mixed"
    local pband = p.dD_label_pred or "mixed"

    local doom_saturated_gold = (gdD >= 0.85) or (gband == "doom-saturated" or gband == "doom-leaning")
    local non_doom_pred       = (pdD < 0.66) and (pband ~= "doom-leaning" and pband ~= "doom-saturated")

    if doom_saturated_gold and non_doom_pred then
      loss = loss + w_miss_d
      breakdown.miss_doom = breakdown.miss_doom + w_miss_d
    end

    for _, dim in ipairs({ "G", "E", "S", "P" }) do
      if not g_hi[dim] and p_hi[dim] then
        loss = loss + w_FP_low
        breakdown.FP_low = breakdown.FP_low + w_FP_low
      end
    end
  end

  return loss, breakdown
end

return M
