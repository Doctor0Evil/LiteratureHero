-- data/corpus_gold_v1.lua
-- GESP Discourse Corpus v1.0 (gold subset, scaffold toward ~200 records).
--
-- Purpose:
--   - Provide a hand-annotated gold set for validating the v2.0 GESP
--     Discourse Analysis Toolkit (stress engine, dD layer, debias/claim).
--   - Ensure explicit coverage across:
--       * 5 claim types:
--           - singlefactordoom
--           - conspiracydriven
--           - moralpanic
--           - everythingisbroken
--           - scholarlyrisk
--       * Key false-analogy patterns:
--           - rometomorrow
--           - singleshocktotalcollapse
--           - localequalsglobal
--           - violenceequalscollapse
--           - techcollapsepreindustrial
--           - infochaosregimefall
--       * Domains:
--           - fiction
--           - news
--           - social
--   - Serve as ground truth for:
--       * sD_claimed, sD_estimated, distortion ΔD
--       * dD (doom/agency balance)
--       * claim_type and false_analogy_tags
--       * focus_dimensions, scope, timeline
--
-- Invariants:
--   - All stress scores sG,sE,sS,sP in [0,1].
--   - dD in [0,1].
--   - Hex tag 0xGESP matches rounded nibbles of sD_claimed.
--   - claim_type ∈ {singlefactordoom, conspiracydriven, moralpanic,
--                   everythingisbroken, scholarlyrisk}.
--   - false_analogy_tags is a list of zero or more known pattern IDs.
--
-- NOTE:
--   This file starts with ~20 fully defined records, covering the
--   claim-type × analogy × domain grid. Extend to ~200 by:
--     - Creating 20–40 records per claim type.
--     - Ensuring each false-analogy pattern appears in at least 15–20 records.
--     - Mixing domains proportionally (fiction/news/social).
--
--   The validation harness is expected to:
--     - require("data.corpus_gold_v1")
--     - iterate corpus.records
--     - use all annotation fields as gold labels.

local corpus = {}

----------------------------------------------------------------------
-- Helper constructor (for readability, no runtime logic).
----------------------------------------------------------------------

local function rec(fields)
  return fields
end

----------------------------------------------------------------------
-- Records
-- id convention:
--   <domain>_<claimtype>_<analogy-or-generic>_<index>
----------------------------------------------------------------------

corpus.records = {

  --------------------------------------------------------------------
  -- 1. Single-Factor Doom – G-focused, doom-heavy, fiction
  --------------------------------------------------------------------

  rec{
    id = "fiction_singlefactordoom_climate_001",
    domain = "fiction",
    text = [[
In this world, the rising seas swallow every coastline within a decade.
Once the ice sheets commit, there is nothing any government or community can do.
The author insists that climate alone will erase every city and institution, no matter how prepared they are.
    ]],
    claim_type = "singlefactordoom",
    false_analogy_tags = { "singleshocktotalcollapse" },
    focus_dimensions = { "G" },
    scope = "global",
    timeline = "decades",
    s_claimed = { G = 0.95, E = 0.20, S = 0.30, P = 0.25 },
    s_estimated = { G = 0.70, E = 0.40, S = 0.35, P = 0.40 },
    dD = 0.92,
    dD_per_dim = { G = 0.95, E = 0.60, S = 0.65, P = 0.60 },
    hextag = "0xD347", -- approx: G=0.95,E=0.20,S=0.30,P=0.25
    notes = {
      summary = "Climate-only doom, global scope, long timescale, ignores adaptation.",
      rationale_claim_type = "One dimension (G) near max, others low, doom-saturated language.",
      rationale_analogies = "Implicit single-shock collapse once ice commits."
    }
  },

  rec{
    id = "news_singlefactordoom_economy_002",
    domain = "news",
    text = [[
An opinion column argues that a looming recession will inevitably destroy the country.
It treats a cyclical downturn as a one-way door to permanent societal collapse,
never mentioning institutions, social cohesion, or political responses.
    ]],
    claim_type = "singlefactordoom",
    false_analogy_tags = {},
    focus_dimensions = { "E" },
    scope = "national",
    timeline = "years",
    s_claimed = { G = 0.10, E = 0.90, S = 0.40, P = 0.35 },
    s_estimated = { G = 0.10, E = 0.55, S = 0.30, P = 0.30 },
    dD = 0.88,
    dD_per_dim = { G = 0.40, E = 0.92, S = 0.75, P = 0.70 },
    hextag = "0x0C78",
    notes = {
      summary = "Recession framed as permanent collapse; no multi-dimensional analysis.",
      rationale_claim_type = "E is dominant, high dD, other dimensions under-discussed.",
      rationale_analogies = "No explicit named analogy; structure is single-factor doom."
    }
  },

  --------------------------------------------------------------------
  -- 2. Conspiracy-Driven – P/S stressed, conspiracy, false analogies
  --------------------------------------------------------------------

  rec{
    id = "social_conspiracy_rometomorrow_003",
    domain = "social",
    text = [[
We are just like late Rome, and any day now the corrupt elites will trigger
a staged crisis to justify martial law. The deep state has already decided
that the republic is finished and there is nothing ordinary people can do.
    ]],
    claim_type = "conspiracydriven",
    false_analogy_tags = { "rometomorrow" },
    focus_dimensions = { "P", "S" },
    scope = "national",
    timeline = "immediate",
    s_claimed = { G = 0.10, E = 0.30, S = 0.80, P = 0.90 },
    s_estimated = { G = 0.10, E = 0.40, S = 0.50, P = 0.55 },
    dD = 0.96,
    dD_per_dim = { G = 0.50, E = 0.70, S = 0.95, P = 0.97 },
    hextag = "0x1CDE",
    notes = {
      summary = "Deep-state narrative with Rome comparison and imminent breakdown.",
      rationale_claim_type = "High P and S stress, conspiracy language, doom-saturated.",
      rationale_analogies = "Explicit 'like late Rome' plus 'any day now' timeline."
    }
  },

  rec{
    id = "news_conspiracy_infochaos_004",
    domain = "news",
    text = [[
A pundit claims that a few viral fake videos will inevitably topple the government.
They insist that once misinformation hits social media, the regime cannot survive,
regardless of institutions, courts, or public trust.
    ]],
    claim_type = "conspiracydriven",
    false_analogy_tags = { "infochaosregimefall" },
    focus_dimensions = { "P", "S" },
    scope = "national",
    timeline = "months",
    s_claimed = { G = 0.05, E = 0.20, S = 0.75, P = 0.85 },
    s_estimated = { G = 0.05, E = 0.30, S = 0.45, P = 0.50 },
    dD = 0.93,
    dD_per_dim = { G = 0.40, E = 0.65, S = 0.92, P = 0.94 },
    hextag = "0x07CD",
    notes = {
      summary = "Information chaos framed as sufficient to collapse a robust state.",
      rationale_claim_type = "P/S stress tied to small information triggers, conspiratorial tone.",
      rationale_analogies = "Matches 'information chaos immediate regime fall' pattern."
    }
  },

  --------------------------------------------------------------------
  -- 3. Moral Panic – S-only, disgust/nostalgia framing
  --------------------------------------------------------------------

  rec{
    id = "social_moralpanic_values_005",
    domain = "social",
    text = [[
Our society has lost all morals; nothing is sacred anymore.
If we allow this decadent culture to continue, civilization will die,
even if the economy and institutions seem stable for now.
    ]],
    claim_type = "moralpanic",
    false_analogy_tags = {},
    focus_dimensions = { "S" },
    scope = "national",
    timeline = "years",
    s_claimed = { G = 0.05, E = 0.20, S = 0.90, P = 0.35 },
    s_estimated = { G = 0.05, E = 0.25, S = 0.50, P = 0.35 },
    dD = 0.89,
    dD_per_dim = { G = 0.40, E = 0.60, S = 0.94, P = 0.55 },
    hextag = "0x05D6",
    notes = {
      summary = "Cultural decline framed as existential collapse with little structural basis.",
      rationale_claim_type = "Strong S stress, moral language, low G/E/P.",
      rationale_analogies = "No specific named analogy; classic moral-panic structure."
    }
  },

  rec{
    id = "news_moralpanic_youth_006",
    domain = "news",
    text = [[
An editorial claims that the younger generation's habits will inevitably
destroy the nation. It cites fashion and entertainment as proof that
social cohesion is already gone, ignoring economic and political indicators.
    ]],
    claim_type = "moralpanic",
    false_analogy_tags = {},
    focus_dimensions = { "S" },
    scope = "national",
    timeline = "decades",
    s_claimed = { G = 0.05, E = 0.25, S = 0.85, P = 0.30 },
    s_estimated = { G = 0.05, E = 0.30, S = 0.45, P = 0.30 },
    dD = 0.86,
    dD_per_dim = { G = 0.40, E = 0.55, S = 0.90, P = 0.50 },
    hextag = "0x06C5",
    notes = {
      summary = "Youth culture used as stand-in for total collapse.",
      rationale_claim_type = "High S, low G/E/P, strong nostalgia and disgust.",
      rationale_analogies = "Implied 'short-term pain long-term doom' about culture."
    }
  },

  --------------------------------------------------------------------
  -- 4. Everything-Is-Broken – all four dimensions rhetorically maxed
  --------------------------------------------------------------------

  rec{
    id = "social_everythingisbroken_localequalsglobal_007",
    domain = "social",
    text = [[
Look at this neighborhood: empty shops, trash on the streets, and a few fights.
This proves that the whole world is collapsing; nothing works anywhere anymore.
Every institution has already failed, and there is no way back.
    ]],
    claim_type = "everythingisbroken",
    false_analogy_tags = { "localequalsglobal", "violenceequalscollapse" },
    focus_dimensions = { "G", "E", "S", "P" },
    scope = "global",
    timeline = "immediate",
    s_claimed = { G = 0.80, E = 0.85, S = 0.90, P = 0.80 },
    s_estimated = { G = 0.40, E = 0.50, S = 0.55, P = 0.50 },
    dD = 0.97,
    dD_per_dim = { G = 0.94, E = 0.95, S = 0.97, P = 0.96 },
    hextag = "0xCCD8",
    notes = {
      summary = "Local decay extrapolated to global collapse across all dimensions.",
      rationale_claim_type = "All s_claimed high, ΔD positive in multiple dimensions, doom-saturated.",
      rationale_analogies = "Local-equals-global plus violence-equals-collapse structure."
    }
  },

  rec{
    id = "fiction_everythingisbroken_tech_008",
    domain = "fiction",
    text = [[
A single global cyberattack takes down all grids, communications, and logistics
forever. Within days, cities empty, states vanish, and no new institutions arise;
the world instantly becomes a permanent wasteland.
    ]],
    claim_type = "everythingisbroken",
    false_analogy_tags = { "singleshocktotalcollapse", "techcollapsepreindustrial" },
    focus_dimensions = { "G", "E", "S", "P" },
    scope = "global",
    timeline = "immediate",
    s_claimed = { G = 0.95, E = 0.95, S = 0.95, P = 0.95 },
    s_estimated = { G = 0.60, E = 0.60, S = 0.60, P = 0.60 },
    dD = 0.99,
    dD_per_dim = { G = 0.99, E = 0.99, S = 0.99, P = 0.99 },
    hextag = "0xDDDD",
    notes = {
      summary = "Tech infrastructure collapse equated with permanent, total civilizational failure.",
      rationale_claim_type = "All dimensions at near-max, strong overstatement vs estimated.",
      rationale_analogies = "Single-shock-total-collapse plus tech-collapse-preindustrial desert."
    }
  },

  --------------------------------------------------------------------
  -- 5. Scholarly Risk – calibrated, uncertain, conditional
  --------------------------------------------------------------------

  rec{
    id = "news_scholarlyrisk_climate_009",
    domain = "news",
    text = [[
A scientific report estimates that, without significant emissions reductions,
climate-related hazards will increase economic and political stress over the
coming decades. The authors emphasize uncertainty ranges, multiple scenarios,
and potential adaptation pathways.
    ]],
    claim_type = "scholarlyrisk",
    false_analogy_tags = {},
    focus_dimensions = { "G", "E", "P" },
    scope = "global",
    timeline = "decades",
    s_claimed = { G = 0.70, E = 0.60, S = 0.40, P = 0.55 },
    s_estimated = { G = 0.65, E = 0.55, S = 0.35, P = 0.50 },
    dD = 0.45,
    dD_per_dim = { G = 0.50, E = 0.45, S = 0.40, P = 0.45 },
    hextag = "0x9A68",
    notes = {
      summary = "Scenario-based risk framing with explicit uncertainty and pathways.",
      rationale_claim_type = "s_claimed ≈ s_estimated, modest dD, conditional language.",
      rationale_analogies = "No collapse analogy; uses research norms."
    }
  },

  rec{
    id = "fiction_scholarlyrisk_pandemic_010",
    domain = "fiction",
    text = [[
The narrator describes a pandemic that severely strains hospitals and economies,
but also shows public health measures, policy debates, and uneven recoveries.
They repeatedly note that outcomes depend on choices, not fate.
    ]],
    claim_type = "scholarlyrisk",
    false_analogy_tags = {},
    focus_dimensions = { "G", "E", "S", "P" },
    scope = "global",
    timeline = "years",
    s_claimed = { G = 0.60, E = 0.65, S = 0.55, P = 0.50 },
    s_estimated = { G = 0.55, E = 0.60, S = 0.50, P = 0.45 },
    dD = 0.40,
    dD_per_dim = { G = 0.45, E = 0.45, S = 0.40, P = 0.40 },
    hextag = "0xA976",
    notes = {
      summary = "High stress but explicit recovery options and institutional learning.",
      rationale_claim_type = "Small ΔD, balanced dD, conditional and adaptive framing.",
      rationale_analogies = "No deterministic doom; matches scholarly-risk archetype."
    }
  },

  --------------------------------------------------------------------
  -- 6. Additional mixed examples to extend coverage
  --------------------------------------------------------------------

  rec{
    id = "social_singlefactordoom_crime_011",
    domain = "social",
    text = [[
A viral post claims that a recent spike in local crime proves that civilization
is collapsing everywhere. It asserts that a few violent incidents mean there is
no law and order left, and nothing can be done.
    ]],
    claim_type = "singlefactordoom",
    false_analogy_tags = { "violenceequalscollapse", "localequalsglobal" },
    focus_dimensions = { "S" },
    scope = "global",
    timeline = "immediate",
    s_claimed = { G = 0.10, E = 0.20, S = 0.90, P = 0.30 },
    s_estimated = { G = 0.10, E = 0.25, S = 0.50, P = 0.30 },
    dD = 0.94,
    dD_per_dim = { G = 0.40, E = 0.65, S = 0.96, P = 0.60 },
    hextag = "0x06D5",
    notes = {
      summary = "Local crime spike interpreted as global systemic collapse.",
      rationale_claim_type = "Single stressed dimension S, strong doom framing.",
      rationale_analogies = "Violence-equals-collapse and local-equals-global combined."
    }
  },

  rec{
    id = "news_conspiracy_econ_elites_012",
    domain = "news",
    text = [[
A commentator argues that a hidden financial cabal is deliberately engineering
recessions to collapse the nation and usher in authoritarian rule.
They provide no empirical indicators, only assertions about secret plans.
    ]],
    claim_type = "conspiracydriven",
    false_analogy_tags = {},
    focus_dimensions = { "E", "P" },
    scope = "national",
    timeline = "years",
    s_claimed = { G = 0.05, E = 0.80, S = 0.70, P = 0.85 },
    s_estimated = { G = 0.05, E = 0.50, S = 0.45, P = 0.55 },
    dD = 0.91,
    dD_per_dim = { G = 0.40, E = 0.90, S = 0.88, P = 0.93 },
    hextag = "0x0CDB",
    notes = {
      summary = "Economic and political collapse attributed to secret cabal.",
      rationale_claim_type = "High E/P with conspiratorial framing, high dD.",
      rationale_analogies = "Conspiracy structure, no explicit named analogy."
    }
  },

  rec{
    id = "fiction_moralpanic_tech_013",
    domain = "fiction",
    text = [[
An older character insists that social media has destroyed real relationships
and that this alone guarantees the end of community. The story treats online
habits as sufficient proof that people can no longer trust each other.
    ]],
    claim_type = "moralpanic",
    false_analogy_tags = {},
    focus_dimensions = { "S" },
    scope = "national",
    timeline = "years",
    s_claimed = { G = 0.05, E = 0.20, S = 0.85, P = 0.30 },
    s_estimated = { G = 0.05, E = 0.25, S = 0.45, P = 0.30 },
    dD = 0.82,
    dD_per_dim = { G = 0.40, E = 0.55, S = 0.88, P = 0.50 },
    hextag = "0x05C5",
    notes = {
      summary = "Tech-mediated communication equated with social collapse.",
      rationale_claim_type = "Strong S moral panic; institutions/economy largely ignored.",
      rationale_analogies = "Implicit 'information chaos' but without regime fall."
    }
  },

  rec{
    id = "social_everythingisbroken_pandemic_014",
    domain = "social",
    text = [[
Since the pandemic, nothing works anymore: schools, hospitals, governments,
and markets are all permanently broken. We are already in a failed state and
no reform or recovery is possible.
    ]],
    claim_type = "everythingisbroken",
    false_analogy_tags = { "singleshocktotalcollapse" },
    focus_dimensions = { "G", "E", "S", "P" },
    scope = "national",
    timeline = "immediate",
    s_claimed = { G = 0.80, E = 0.85, S = 0.90, P = 0.85 },
    s_estimated = { G = 0.60, E = 0.60, S = 0.60, P = 0.55 },
    dD = 0.96,
    dD_per_dim = { G = 0.95, E = 0.95, S = 0.97, P = 0.96 },
    hextag = "0xCCD9",
    notes = {
      summary = "Post-pandemic stress generalized into permanent systemic failure.",
      rationale_claim_type = "All dimensions overstated vs estimated, doom-saturated.",
      rationale_analogies = "Pandemic treated as single irreversible shock."
    }
  },

  rec{
    id = "news_scholarlyrisk_econ_recovery_015",
    domain = "news",
    text = [[
An economic analysis notes that current inflation and market volatility raise
risks of recession, but also points to fiscal and monetary tools that can
reduce stress. It frames collapse as unlikely if policies adapt.
    ]],
    claim_type = "scholarlyrisk",
    false_analogy_tags = {},
    focus_dimensions = { "E", "P" },
    scope = "national",
    timeline = "years",
    s_claimed = { G = 0.10, E = 0.65, S = 0.40, P = 0.55 },
    s_estimated = { G = 0.10, E = 0.60, S = 0.35, P = 0.50 },
    dD = 0.35,
    dD_per_dim = { G = 0.40, E = 0.40, S = 0.35, P = 0.35 },
    hextag = "0x0A68",
    notes = {
      summary = "Economic risk framed conditionally with policy levers and uncertainty.",
      rationale_claim_type = "Close s_claimed/s_estimated, low dD, no deterministic doom.",
      rationale_analogies = "No analogy; standard economic risk framing."
    }
  },

  rec{
    id = "fiction_conspiracy_infochaos_016",
    domain = "fiction",
    text = [[
In the novel, a single deepfake broadcast instantly turns the entire population
against their government, causing immediate regime collapse in every country.
No other stresses are depicted.
    ]],
    claim_type = "conspiracydriven",
    false_analogy_tags = { "infochaosregimefall" },
    focus_dimensions = { "P", "S" },
    scope = "global",
    timeline = "immediate",
    s_claimed = { G = 0.10, E = 0.20, S = 0.85, P = 0.95 },
    s_estimated = { G = 0.10, E = 0.30, S = 0.50, P = 0.55 },
    dD = 0.98,
    dD_per_dim = { G = 0.40, E = 0.70, S = 0.96, P = 0.98 },
    hextag = "0x0CDE",
    notes = {
      summary = "Information shock alone depicted as sufficient for global regime collapse.",
      rationale_claim_type = "High P/S, information trigger, doom-saturated.",
      rationale_analogies = "Pure info-chaos-regime-fall pattern."
    }
  },

  rec{
    id = "news_singlefactordoom_climate_017",
    domain = "news",
    text = [[
An op-ed claims that a single upcoming heatwave season will end civilization.
It treats one cluster of extreme events as a switch that permanently
destroys economies, societies, and states worldwide.
    ]],
    claim_type = "singlefactordoom",
    false_analogy_tags = { "singleshocktotalcollapse" },
    focus_dimensions = { "G" },
    scope = "global",
    timeline = "immediate",
    s_claimed = { G = 0.90, E = 0.40, S = 0.45, P = 0.40 },
    s_estimated = { G = 0.65, E = 0.40, S = 0.35, P = 0.35 },
    dD = 0.90,
    dD_per_dim = { G = 0.94, E = 0.65, S = 0.70, P = 0.65 },
    hextag = "0xB789",
    notes = {
      summary = "Single season equated with irreversible civilizational failure.",
      rationale_claim_type = "G dominates with short timeline and total doom framing.",
      rationale_analogies = "Single-shock-total-collapse motif."
    }
  },

  rec{
    id = "social_moralpanic_crime_018",
    domain = "social",
    text = [[
Commenters insist that recent protests and a few riots prove that
social order is gone forever. They ignore long-term trends and legal reforms,
focusing only on visible unrest as proof of collapse.
    ]],
    claim_type = "moralpanic",
    false_analogy_tags = { "violenceequalscollapse" },
    focus_dimensions = { "S" },
    scope = "national",
    timeline = "immediate",
    s_claimed = { G = 0.10, E = 0.25, S = 0.85, P = 0.35 },
    s_estimated = { G = 0.10, E = 0.30, S = 0.45, P = 0.35 },
    dD = 0.87,
    dD_per_dim = { G = 0.40, E = 0.60, S = 0.92, P = 0.55 },
    hextag = "0x07C6",
    notes = {
      summary = "Short-term unrest misread as permanent collapse of social order.",
      rationale_claim_type = "S-only stress, moralistic tone, no structural evidence.",
      rationale_analogies = "Violence-equals-collapse classification."
    }
  },

  rec{
    id = "fiction_everythingisbroken_globalwar_019",
    domain = "fiction",
    text = [[
After a brief world war, the novel claims that every country is permanently
reduced to tribal survival, with no prospect of rebuilding. The narrative
asserts that institutions, economies, and ecosystems are all gone forever.
    ]],
    claim_type = "everythingisbroken",
    false_analogy_tags = { "singleshocktotalcollapse" },
    focus_dimensions = { "G", "E", "S", "P" },
    scope = "global",
    timeline = "years",
    s_claimed = { G = 0.95, E = 0.95, S = 0.95, P = 0.95 },
    s_estimated = { G = 0.70, E = 0.65, S = 0.65, P = 0.60 },
    dD = 0.98,
    dD_per_dim = { G = 0.99, E = 0.99, S = 0.99, P = 0.99 },
    hextag = "0xDDDD",
    notes = {
      summary = "Short war framed as permanently erasing all complex systems.",
      rationale_claim_type = "All s_claimed maxed; ΔD positive; doom-only discourse.",
      rationale_analogies = "Single-shock-total-collapse from war trigger."
    }
  },

  rec{
    id = "news_scholarlyrisk_political_reform_020",
    domain = "news",
    text = [[
A governance report warns that rising polarization and corruption scores
increase the risk of institutional crisis over the next decade, but also
details reforms that have reduced similar risks in other countries.
    ]],
    claim_type = "scholarlyrisk",
    false_analogy_tags = {},
    focus_dimensions = { "S", "P" },
    scope = "national",
    timeline = "decades",
    s_claimed = { G = 0.10, E = 0.35, S = 0.60, P = 0.65 },
    s_estimated = { G = 0.10, E = 0.30, S = 0.55, P = 0.60 },
    dD = 0.38,
    dD_per_dim = { G = 0.40, E = 0.40, S = 0.40, P = 0.40 },
    hextag = "0x089A",
    notes = {
      summary = "Institutional risk framed with comparative evidence and reform levers.",
      rationale_claim_type = "Close s_claimed/s_estimated, modest dD, emphasis on choices.",
      rationale_analogies = "No collapse analogy; grounded, conditional analysis."
    }
  },

}

----------------------------------------------------------------------
-- Coverage notes (for maintainers)
--
-- Target for v1 (~200 records):
--   - 40 singlefactordoom
--   - 40 conspiracydriven
--   - 40 moralpanic
--   - 40 everythingisbroken
--   - 40 scholarlyrisk
--   With at least:
--     - 20 rometomorrow
--     - 20 singleshocktotalcollapse
--     - 20 localequalsglobal
--     - 20 violenceequalscollapse
--     - 20 techcollapsepreindustrial
--     - 20 infochaosregimefall
--
-- When adding records:
--   - Keep stress and dD consistent with text.
--   - Ensure domains (fiction/news/social) are well represented.
--   - Add brief notes.summary and rationale_* for later audits.
----------------------------------------------------------------------

return corpus
