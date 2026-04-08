-- src/tools/risk_scorer.lua
--
-- LiteratureHero Risk Scoring Tool
--
-- This module aggregates per-invariant scores into composite risk indices.
-- It is deliberately simple and table-driven:
--   - invariant_scores: list of { name = "unity_hivemind", normalized = 0.0–1.0, ... }
--   - config: usually lh_config.risk_weights, see example at bottom of file
--
-- Output:
--   {
--     indices = {
--       autonomy_risk = 0.72,
--       doomsday_escalation_risk = 0.35,
--       tech_capture_risk = 0.65
--     },
--     per_index_details = {
--       autonomy_risk = {
--         contributions = {
--           { invariant = "unity_hivemind", weight = 0.5, score = 0.9, weighted = 0.45 },
--           { invariant = "utopian_principles", weight = 0.5, score = 0.99, weighted = 0.495 }
--         },
--         raw_sum = 0.945,
--         normalized = 0.95
--       },
--       ...
--     }
--   }

local risk_scorer = {}

----------------------------------------------------------------------
-- Utility: build a lookup table from invariant_scores list
----------------------------------------------------------------------

local function index_scores_by_name(invariant_scores)
  local by_name = {}
  for _, item in ipairs(invariant_scores or {}) do
    if item.name then
      by_name[item.name] = item
    end
  end
  return by_name
end

----------------------------------------------------------------------
-- Core: compute a single composite index from weights + scores
--
-- index_spec example:
--   {
--     name = "autonomy_risk",
--     invariants = {
--       { name = "unity_hivemind", weight = 0.5 },
--       { name = "utopian_principles", weight = 0.5 }
--     },
--     -- optional cap for normalization
--     max_expected = 1.0
--   }
----------------------------------------------------------------------

local function compute_index(index_spec, score_lookup)
  local contributions = {}
  local raw_sum = 0.0
  local total_weight = 0.0

  for _, entry in ipairs(index_spec.invariants or {}) do
    local inv_name = entry.name
    local weight = entry.weight or 0.0
    total_weight = total_weight + weight

    local score_obj = score_lookup[inv_name]
    local score = 0.0
    if score_obj and type(score_obj.normalized) == "number" then
      score = score_obj.normalized
    end

    local weighted = score * weight
    raw_sum = raw_sum + weighted

    contributions[#contributions + 1] = {
      invariant = inv_name,
      weight = weight,
      score = score,
      weighted = weighted
    }
  end

  -- Normalize by sum of weights (so we stay in 0..1 if all scores are 0..1)
  local normalized = 0.0
  if total_weight > 0 then
    normalized = raw_sum / total_weight
  end

  -- Optionally cap by a configured "max_expected" (for safety)
  local max_expected = index_spec.max_expected or 1.0
  if max_expected > 0 then
    normalized = math.min(normalized, max_expected)
  end

  return {
    name = index_spec.name,
    raw_sum = raw_sum,
    normalized = normalized,
    contributions = contributions
  }
end

----------------------------------------------------------------------
-- Public API: compute all configured indices
--
-- invariant_scores: list of { name = "...", normalized = number, ... }
-- risk_weights: config table with a structure like:
--
-- risk_weights = {
--   indices = {
--     autonomy_risk = {
--       invariants = {
--         { name = "unity_hivemind", weight = 0.5 },
--         { name = "utopian_principles", weight = 0.5 }
--       },
--       max_expected = 1.0
--     },
--     doomsday_escalation_risk = {
--       invariants = {
--         { name = "doomsday_prophecy", weight = 0.6 },
--         { name = "sacred_violence", weight = 0.4 }
--       },
--       max_expected = 1.0
--     },
--     tech_capture_risk = {
--       invariants = {
--         { name = "tech_gatekeeping", weight = 0.7 },
--         { name = "information_control", weight = 0.3 }
--       },
--       max_expected = 1.0
--     }
--   }
-- }
----------------------------------------------------------------------

function risk_scorer.compute(invariant_scores, risk_weights)
  local score_lookup = index_scores_by_name(invariant_scores)
  local indices_cfg = (risk_weights and risk_weights.indices) or {}

  local indices = {}
  local per_index_details = {}

  -- iterate deterministic (sorted keys) for stable output
  local index_names = {}
  for k, _ in pairs(indices_cfg) do
    index_names[#index_names + 1] = k
  end
  table.sort(index_names)

  for _, idx_name in ipairs(index_names) do
    local spec = indices_cfg[idx_name]
    spec.name = idx_name
    local detail = compute_index(spec, score_lookup)
    indices[idx_name] = detail.normalized
    per_index_details[idx_name] = detail
  end

  return {
    indices = indices,
    per_index_details = per_index_details
  }
end

----------------------------------------------------------------------
-- Example configuration snippet (for lh_config.lua)
--
-- In lh_config.lua you might have:
--
-- local M = {}
--
-- M.risk_weights = {
--   indices = {
--     autonomy_risk = {
--       invariants = {
--         { name = "unity_hivemind", weight = 0.6 },
--         { name = "utopian_principles", weight = 0.4 }
--       },
--       max_expected = 1.0
--     },
--     doomsday_escalation_risk = {
--       invariants = {
--         { name = "doomsday_prophecy", weight = 0.7 },
--         { name = "sacred_violence", weight = 0.3 }
--       },
--       max_expected = 1.0
--     },
--     tech_capture_risk = {
--       invariants = {
--         { name = "tech_gatekeeping", weight = 0.7 },
--         { name = "information_control", weight = 0.3 }
--       },
--       max_expected = 1.0
--     }
--   }
-- }
--
-- return M
--
-- Then from lh_engine.lua:
--
--   local lh_config = require("core.lh_config")
--   local risk_scorer = require("tools.risk_scorer")
--
--   local invariant_scores = invariant_registry.run_all(...)
--   local risk_result = risk_scorer.compute(invariant_scores, lh_config.risk_weights)
--
--   analysis_result.risk_indices = risk_result.indices
--   analysis_result.risk_details = risk_result.per_index_details
----------------------------------------------------------------------

return risk_scorer
