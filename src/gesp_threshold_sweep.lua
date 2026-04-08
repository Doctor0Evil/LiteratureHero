-- src/gesp_threshold_sweep.lua
-- GESP Threshold Sweep and Safety-Weighted Calibration Harness
--
-- USR: 0x9D (high research usefulness, safety-first, hex-tagged)
-- GESP tag: 0xACDF  (Geo/Eco/Social/Political coverage, collapse dynamics)
--
-- ROLE
--   This module wraps the existing src/gesp_validation_harness.lua and
--   tools/eval/metrics_and_loss.lua to run a structured sweep over
--   stress / dD / claim-type thresholds and cost weights.
--
--   It:
--     - Delegates all per-record analysis to the existing analyzers
--       (src/gesp_discourse_analyzer.lua, src/gesp_debias_analyzer.lua,
--        src/claim_classifier.lua, src/doom_agency_decoder.lua).
--     - Uses the validation harness as a pure evaluation oracle.
--     - Sweeps threshold grids and cost-weight λ ranges.
--     - Enforces safety-first optimization (high-cost FN on S/P & doom).
--     - Emits JSON + CSV + Markdown artifacts for audit-ready calibration.
--
--   It is intentionally a *thin orchestration layer*; no thresholds are
--   hard-coded elsewhere. All bands / cutpoints live in this sweep and
--   in small config tables, keeping the repo’s contracts stable.
--
--   Typical invocation:
--     lua src/gesp_threshold_sweep.lua
--
-- COMPATIBILITY
--   - Must stay compatible with:
--       src/gesp_validation_harness.lua
--       tools/eval/metrics_and_loss.lua
--       data/corpus_gold_v1.lua
--   - Does not change any of their contracts; only calls them.

----------------------------------------------------------------------
-- 0. Requires and wiring
----------------------------------------------------------------------

local ok_json, cjson = pcall(require, "cjson")
local json = ok_json and cjson or nil

-- Existing gold corpus + harness + metrics stack.
local GoldCorpus = require("data.corpus_gold_v1")              -- .records
local ValidationHarness = require("src.gesp_validation_harness") -- run(config) -> metrics, logs
local MetricsAndLoss = require("tools.eval.metrics_and_loss")    -- cost-sensitive logic, registry

----------------------------------------------------------------------
-- 1. Global configuration for sweep
----------------------------------------------------------------------

local OUTPUT_DIR  = "output"
local REPORT_DIR  = "reports"
local SWEEP_ID    = os.date("gesp_threshold_sweep_%Y%m%d_%H%M%S")

-- Hex-tagged metadata for USR and G/E/S/P coverage.
local META = {
  gesp_hex = "0xACDF",
  usr_hex  = "0x9D",
  role     = "Threshold calibration + safety-weight sweep for GESP + dD stack"
}

-- Default grids, chosen to be small but expandable.
local CONFIG = {
  -- Threshold grids (used by the harness via injected config)
  t_dom_grid     = { 0.55, 0.65, 0.75 },  -- dominant-dimension stress
  t_all_grid     = { 0.40, 0.50, 0.60 },  -- “everything high” stress
  t_doom_grid    = { 0.70, 0.80, 0.90 },  -- doom-saturation for d/dD

  -- Band quantiles for dD (low/high); same across G/E/S/P by invariant.
  dD_quantiles   = {
    { q_low = 0.25, q_high = 0.75 },
    { q_low = 0.20, q_high = 0.80 },
    { q_low = 0.30, q_high = 0.70 }
  },

  -- λ sweep (safety vs macro-F1). Safety-first invariant: λ_cost » λ_macro.
  lambda_cost_grid  = { 1.0, 1.5 },
  lambda_macro_grid = { 0.1, 0.2 },

  -- Domain degradation flags (relative).
  max_delta_F1_domain = 0.10,  -- >0.10 drop in macro-F1 flags degradation
  max_rel_cost_domain = 0.20,  -- >0.20 relative cost increase flags degradation
}

----------------------------------------------------------------------
-- 2. Simple utilities
----------------------------------------------------------------------

local function ensure_dir(path)
  os.execute(string.format("mkdir -p %s", path))
end

local function safediv(num, den)
  den = den or 0
  if den == 0 then return 0 end
  return num / den
end

local function get_domain(rec)
  local src = (rec.context_source or rec.context_domain or "other"):lower()
  if src:find("fiction") then return "fiction" end
  if src:find("news")    then return "news"    end
  if src:find("social")  then return "social"  end
  return "other"
end

----------------------------------------------------------------------
-- 3. Harness adapter: inject θ (thresholds, bands, λ) into validation
----------------------------------------------------------------------

-- By design, src/gesp_validation_harness.lua exposes a single run(config)
-- entrypoint that:
--   - Reads the gold corpus (or accepts it via config.records).
--   - Calls analyzers.
--   - Returns a metrics table + optional logs.
--
-- We treat it here as a black box with one extension point:
--   config.thresholds, config.dD_bands, config.cost_weights
-- The harness should already be wired to consume these if present.

local function build_harness_config(theta, base_overrides)
  base_overrides = base_overrides or {}

  local cfg = {
    sweep_id   = SWEEP_ID,
    theta      = theta,
    meta       = META,
    thresholds = {
      t_dom  = theta.t_dom,
      t_all  = theta.t_all,
      t_doom = theta.t_doom
    },
    dD_bands = {
      q_low  = theta.q_low,
      q_high = theta.q_high
    },
    cost_weights = {
      lambda_cost  = theta.lambda_cost,
      lambda_macro = theta.lambda_macro
    },
    records = GoldCorpus.records or {}
  }

  -- Allow the caller to override/extend any fields.
  for k, v in pairs(base_overrides) do
    cfg[k] = v
  end

  return cfg
end

----------------------------------------------------------------------
-- 4. Objective J: safety-weighted cost + macro-F1
----------------------------------------------------------------------

-- We assume ValidationHarness.run(config) returns a metrics table with:
--   metrics.cost.L_cost                      (scalar)
--   metrics.claimtype.macro_f1               (scalar)
--   metrics.domain[dom].L_cost, .macro_f1    (per-domain)
--   metrics.confusion.claimtype_matrix       (for MP vs EIB tracking)
--   metrics.disagreement.*                   (for annotator A/B vs neither)
--
-- If these fields are missing, we fall back gracefully and keep
-- the harness contracts intact.

local function extract_scalar_metrics(metrics)
  local L_cost  = 0
  local macroF1 = 0

  if metrics.cost and metrics.cost.L_cost then
    L_cost = metrics.cost.L_cost
  elseif MetricsAndLoss and MetricsAndLoss.global_cost_from_metrics then
    L_cost = MetricsAndLoss.global_cost_from_metrics(metrics)
  end

  if metrics.claimtype and metrics.claimtype.macro_f1 then
    macroF1 = metrics.claimtype.macro_f1
  elseif MetricsAndLoss and MetricsAndLoss.global_macroF1_from_metrics then
    macroF1 = MetricsAndLoss.global_macroF1_from_metrics(metrics)
  end

  return L_cost, macroF1
end

local function compute_J(L_cost, macroF1, theta)
  return - theta.lambda_cost * L_cost + theta.lambda_macro * macroF1
end

----------------------------------------------------------------------
-- 5. Single θ run: call harness, collect global/domain/error metrics
----------------------------------------------------------------------

local function run_single_theta(theta)
  local harness_cfg = build_harness_config(theta)
  local metrics, logs = ValidationHarness.run(harness_cfg)

  local L_cost, macroF1 = extract_scalar_metrics(metrics)
  local J = compute_J(L_cost, macroF1, theta)

  -- Domain-specific metrics.
  local domain_metrics = {}
  if metrics.domain then
    for dom, dm in pairs(metrics.domain) do
      domain_metrics[dom] = {
        L_cost  = dm.L_cost or 0,
        macro_f1 = dm.macro_f1 or 0
      }
    end
  end

  -- Moral Panic vs Everything-Is-Broken confusion counts.
  local mp_to_eib, eib_to_mp = 0, 0
  if metrics.confusion and metrics.confusion.claimtype_matrix then
    local cm = metrics.confusion.claimtype_matrix
    local MP = "Moral Panic"
    local EIB = "Everything-Is-Broken"
    if cm[MP] and cm[MP][EIB] then mp_to_eib = cm[MP][EIB] end
    if cm[EIB] and cm[EIB][MP] then eib_to_mp = cm[EIB][MP] end
  end

  -- Annotator disagreement metrics: alignment with A vs B vs neither.
  local disagree_macroF1, align_A, align_B, align_neither = 0, 0, 0, 0
  if metrics.disagreement then
    disagree_macroF1 = metrics.disagreement.macro_f1 or 0
    align_A          = metrics.disagreement.align_A or 0
    align_B          = metrics.disagreement.align_B or 0
    align_neither    = metrics.disagreement.align_neither or 0
  end

  return {
    theta            = theta,
    metrics          = metrics,
    logs             = logs,
    L_cost           = L_cost,
    macroF1          = macroF1,
    J                = J,
    domain_metrics   = domain_metrics,
    mp_to_eib        = mp_to_eib,
    eib_to_mp        = eib_to_mp,
    disagree_macroF1 = disagree_macroF1,
    disagree_align   = {
      A       = align_A,
      B       = align_B,
      neither = align_neither
    }
  }
end

----------------------------------------------------------------------
-- 6. Sweep over θ grid
----------------------------------------------------------------------

local function run_sweep()
  ensure_dir(OUTPUT_DIR)
  ensure_dir(REPORT_DIR)

  local records = GoldCorpus.records or {}
  if #records == 0 then
    print("[gesp_threshold_sweep] No gold records; aborting.")
    return
  end

  print(string.format("[gesp_threshold_sweep] Loaded %d gold records.", #records))

  local results = {}

  for _, t_dom in ipairs(CONFIG.t_dom_grid) do
    for _, t_all in ipairs(CONFIG.t_all_grid) do
      for _, t_doom in ipairs(CONFIG.t_doom_grid) do
        for _, q_pair in ipairs(CONFIG.dD_quantiles) do
          for _, lambda_cost in ipairs(CONFIG.lambda_cost_grid) do
            for _, lambda_macro in ipairs(CONFIG.lambda_macro_grid) do
              local theta = {
                t_dom        = t_dom,
                t_all        = t_all,
                t_doom       = t_doom,
                q_low        = q_pair.q_low,
                q_high       = q_pair.q_high,
                lambda_cost  = lambda_cost,
                lambda_macro = lambda_macro
              }

              local res = run_single_theta(theta)
              results[#results+1] = res

              print(string.format(
                "[θ] t_dom=%.2f t_all=%.2f t_doom=%.2f q=(%.2f,%.2f) λ_c=%.2f λ_F1=%.2f | F1=%.3f L=%.1f J=%.3f",
                t_dom, t_all, t_doom,
                q_pair.q_low, q_pair.q_high,
                lambda_cost, lambda_macro,
                res.macroF1, res.L_cost, res.J
              ))
            end
          end
        end
      end
    end
  end

  if #results == 0 then
    print("[gesp_threshold_sweep] No results produced; aborting.")
    return
  end

  -- Select best J under safety-first objective.
  local best_idx, best_J = nil, nil
  for i, r in ipairs(results) do
    if not best_J or r.J > best_J then
      best_J  = r.J
      best_idx = i
    end
  end
  local best = results[best_idx]

  print("[gesp_threshold_sweep] Selected global best θ*:")
  print(string.format(
    "  t_dom=%.2f t_all=%.2f t_doom=%.2f q=(%.2f,%.2f) λ_c=%.2f λ_F1=%.2f | F1=%.3f L=%.1f J=%.3f",
    best.theta.t_dom, best.theta.t_all, best.theta.t_doom,
    best.theta.q_low, best.theta.q_high,
    best.theta.lambda_cost, best.theta.lambda_macro,
    best.macroF1, best.L_cost, best.J
  ))

  --------------------------------------------------------------------
  -- 7. Domain degradation analysis
  --------------------------------------------------------------------

  local global_F1   = best.macroF1
  local global_cost = best.L_cost

  local domain_flags = {}
  for dom, dm in pairs(best.domain_metrics or {}) do
    local dF1 = global_F1 - (dm.macro_f1 or 0)
    local rel_cost = 0
    if dm.L_cost and global_cost > 0 then
      rel_cost = (dm.L_cost - global_cost) / global_cost
    end

    domain_flags[dom] = {
      delta_macroF1      = dF1,
      rel_cost_increase  = rel_cost,
      flag_F1            = dF1 > CONFIG.max_delta_F1_domain,
      flag_cost          = rel_cost > CONFIG.max_rel_cost_domain
    }
  end

  --------------------------------------------------------------------
  -- 8. JSON config export for θ*
  --------------------------------------------------------------------

  if json then
    local json_path = string.format("%s/%s_best.json", OUTPUT_DIR, SWEEP_ID)
    local payload = {
      sweep_id   = SWEEP_ID,
      meta       = META,
      theta      = best.theta,
      metrics    = {
        macroF1          = best.macroF1,
        L_cost           = best.L_cost,
        J                = best.J,
        mp_to_eib        = best.mp_to_eib,
        eib_to_mp        = best.eib_to_mp,
        disagree_macroF1 = best.disagree_macroF1,
        disagree_align   = best.disagree_align
      },
      domains    = domain_flags
    }

    local fh = io.open(json_path, "w")
    if fh then
      fh:write(json.encode(payload))
      fh:close()
      print("[gesp_threshold_sweep] Wrote best config JSON: " .. json_path)
    end
  end

  --------------------------------------------------------------------
  -- 9. CSV grid export
  --------------------------------------------------------------------

  local csv_path = string.format("%s/%s_grid.csv", OUTPUT_DIR, SWEEP_ID)
  local fh_csv = io.open(csv_path, "w")
  if fh_csv then
    fh_csv:write("t_dom,t_all,t_doom,q_low,q_high,lambda_cost,lambda_macro,macroF1,L_cost,J,mp_to_eib,eib_to_mp,disagree_macroF1\n")
    for _, r in ipairs(results) do
      fh_csv:write(string.format(
        "%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.4f,%.2f,%.4f,%d,%d,%.4f\n",
        r.theta.t_dom, r.theta.t_all, r.theta.t_doom,
        r.theta.q_low, r.theta.q_high,
        r.theta.lambda_cost, r.theta.lambda_macro,
        r.macroF1, r.L_cost, r.J,
        r.mp_to_eib or 0, r.eib_to_mp or 0,
        r.disagree_macroF1 or 0
      ))
    end
    fh_csv:close()
    print("[gesp_threshold_sweep] Wrote grid CSV: " .. csv_path)
  end

  --------------------------------------------------------------------
  -- 10. Markdown summary for GitHub
  --------------------------------------------------------------------

  local md_path = string.format("%s/%s_summary.md", REPORT_DIR, SWEEP_ID)
  local fh_md = io.open(md_path, "w")
  if fh_md then
    fh_md:write("# GESP Threshold + Cost Sweep Summary\n\n")
    fh_md:write(string.format("- Sweep ID: `%s`\n", SWEEP_ID))
    fh_md:write(string.format("- GESP hex tag: `%s`\n", META.gesp_hex))
    fh_md:write(string.format("- USR (usefulness) tag: `%s`\n\n", META.usr_hex))

    fh_md:write("## Best Global Configuration\n\n")
    fh_md:write(string.format(
      "- `t_dom` (dominant-dimension stress): **%.2f**\n" ..
      "- `t_all` (everything-is-high threshold): **%.2f**\n" ..
      "- `t_doom` (doom-saturation d/dD): **%.2f**\n" ..
      "- dD quantiles: `q_low=%.2f`, `q_high=%.2f`\n" ..
      "- `lambda_cost`: **%.2f** (safety weight)\n" ..
      "- `lambda_macro`: **%.2f** (macro-F1 weight)\n\n",
      best.theta.t_dom, best.theta.t_all, best.theta.t_doom,
      best.theta.q_low, best.theta.q_high,
      best.theta.lambda_cost, best.theta.lambda_macro
    ))

    fh_md:write(string.format(
      "- Global macro-F1 (claim types): **%.3f**\n" ..
      "- Global safety-weighted loss `L_cost`: **%.1f**\n" ..
      "- Combined objective `J = -λ_cost·L_cost + λ_macro·F1_macro`: **%.3f**\n\n",
      best.macroF1, best.L_cost, best.J
    ))

    fh_md:write("### Moral Panic vs Everything-Is-Broken\n\n")
    fh_md:write(string.format(
      "- Moral Panic → Everything-Is-Broken confusions: **%d**\n" ..
      "- Everything-Is-Broken → Moral Panic confusions: **%d**\n\n",
      best.mp_to_eib or 0, best.eib_to_mp or 0
    ))

    fh_md:write("### Annotator Disagreement Slice\n\n")
    fh_md:write(string.format(
      "- Disagreement macro-F1: **%.3f**\n" ..
      "- Align with annotator A: **%d**\n" ..
      "- Align with annotator B: **%d**\n" ..
      "- Align with neither: **%d**\n\n",
      best.disagree_macroF1 or 0,
      best.disagree_align.A or 0,
      best.disagree_align.B or 0,
      best.disagree_align.neither or 0
    ))

    fh_md:write("## Domain Robustness and Degradation Flags\n\n")
    for _, dom in ipairs({ "fiction", "news", "social", "other" }) do
      local dm   = best.domain_metrics[dom] or {}
      local flag = domain_flags[dom] or {}

      fh_md:write(string.format("### %s\n\n", dom:gsub("^%l", string.upper)))
      fh_md:write(string.format(
        "- Domain macro-F1: **%.3f**\n" ..
        "- Δ macro-F1 vs global: **%.3f**\n" ..
        "- Relative cost increase vs global: **%.3f**\n",
        dm.macro_f1 or 0,
        flag.delta_macroF1 or 0,
        flag.rel_cost_increase or 0
      ))

      if flag.flag_F1 or flag.flag_cost then
        fh_md:write("- **Degradation flagged**: consider domain-specific tuning thresholds.\n\n")
      else
        fh_md:write("- No severe degradation under current configuration.\n\n")
      end
    end

    fh_md:write("## Notes and Next Steps\n\n")
    fh_md:write("- This sweep treats safety-critical cost (high S/P stress FN and doom-saturated mislabels) as the primary optimization target.\n")
    fh_md:write("- Thresholds selected here can be written back into the shared config and used by src/gesp_validation_harness.lua as defaults.\n")
    fh_md:write("- The CSV grid can be used to visualize trade-offs between macro-F1, cost, and Moral Panic vs Everything-Is-Broken confusions.\n")

    fh_md:close()
    print("[gesp_threshold_sweep] Wrote Markdown summary: " .. md_path)
  end
end

----------------------------------------------------------------------
-- 11. Entry point
----------------------------------------------------------------------

run_sweep()
