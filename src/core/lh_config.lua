-- src/core/lh_config.lua
--
-- Global configuration for LiteratureHero.
-- This file is intentionally simple and table-driven so analysts
-- can tune behavior without touching engine code.

local M = {}

----------------------------------------------------------------------
-- General settings
----------------------------------------------------------------------

-- Base directory for input corpora (you can override per-work)
M.data_root = "data"

-- Default directory for markdown and JSON reports
M.output_root = "output"

-- Maximum number of evidence snippets to include per invariant
M.max_evidence_snippets = 10

----------------------------------------------------------------------
-- Invariant weighting for composite risk indices
--
-- These weights feed into src/tools/risk_scorer.lua.
-- All scores are 0..1, and weights express relative importance.
----------------------------------------------------------------------

M.risk_weights = {
  indices = {
    autonomy_risk = {
      invariants = {
        { name = "unity_hivemind", weight = 0.6 },
        { name = "utopian_principles_weaponized", weight = 0.4 }
      },
      max_expected = 1.0
    },

    doomsday_escalation_risk = {
      invariants = {
        { name = "doomsday_prophecy", weight = 0.7 },
        { name = "sacred_violence", weight = 0.3 }
      },
      max_expected = 1.0
    },

    tech_capture_risk = {
      invariants = {
        { name = "tech_gatekeeping", weight = 0.7 },
        { name = "information_control", weight = 0.3 }
      },
      max_expected = 1.0
    },

    epistemic_fragility_risk = {
      invariants = {
        { name = "AUTHORITY_MASK", weight = 0.25 },
        { name = "CHAIN_OF_EVIDENCE", weight = 0.25 },
        { name = "EDGE_OF_BELIEVABILITY", weight = 0.25 },
        { name = "REFRAME_FOUNDING_MYTH", weight = 0.25 }
      },
      max_expected = 1.0
    }
  }
}

----------------------------------------------------------------------
-- Scenario ranking weights
--
-- Used by src/analysis/scenario_ranker.lua to compute a
-- cross-text "collapse proximity" index.
----------------------------------------------------------------------

M.scenario_weights = {
  -- Focus on the high-risk convergence you care about most
  unity_hivemind = 1.0,
  tech_gatekeeping = 0.9,
  utopian_principles_weaponized = 0.7,
  doomsday_sacred_combo = 1.0
}

----------------------------------------------------------------------
-- Hoax detector tuning
--
-- These thresholds are optional and can be used later if you want
-- to treat a hoax index as "present" or "strong" in a scenario.
----------------------------------------------------------------------

M.hoax_thresholds = {
  weak = 0.25,
  moderate = 0.5,
  strong = 0.75
}

----------------------------------------------------------------------
-- Default tokenizer options
--
-- These flags are referenced by src/nlp/tokenizer.lua
-- if you want to tweak behavior without editing that file.
----------------------------------------------------------------------

M.tokenizer = {
  -- If true, store multi-word phrase hits in sentence.phrases
  detect_phrases = true,

  -- Minimum token length to keep (e.g., ignore 1-char tokens)
  min_token_length = 1
}

----------------------------------------------------------------------
-- Faction analysis settings
----------------------------------------------------------------------

M.factions = {
  -- If true, faction comparison tables will appear in markdown reports
  include_markdown_tables = true
}

----------------------------------------------------------------------
-- Helper: convenience function to resolve paths
-- (optional, not required by core engine but often handy).
----------------------------------------------------------------------

function M.join_path(root, sub)
  if not root or root == "" then
    return sub
  end
  if not sub or sub == "" then
    return root
  end
  local last = string.sub(root, -1)
  if last == "/" or last == "\\" then
    return root .. sub
  else
    return root .. "/" .. sub
  end
end

return M
