-- Core LiteratureHero analysis engine (dependency-free)

-- Core IO and preprocessing
local text_loader       = require("src.io.text_loader")
local tokenizer         = require("src.nlp.tokenizer")

-- Invariant system
local invariant_registry = require("src.invariants.invariant_registry")
local invariant_graph    = require("src.analysis.invariant_graph")
local institutional_recs = require("src.analysis.institutional_recommendations")

-- Optional higher-level analyzers (comment out if not implemented yet)
local hoax_detector      = require("src.analysis.hoax_detector")
local faction_analyzer   = require("src.analysis.faction_comparator")
local risk_scorer        = require("src.tools.risk_scorer")
local education_builder  = require("src.analysis.education_builder")
local indicator_builder  = require("src.analysis.indicator_builder")

local lh_engine = {}

--[[
spec = {
  id = "mycelium_atom_rpg",
  title = "Mycelium Cult – Atom RPG",
  source_files = { "data/mycelium_lore.txt" },
  tags = {"fiction", "post_apocalyptic", "cult"}
}
]]

function lh_engine.analyze(spec, opts)
  opts = opts or {}

  -- 1. Load and tokenize documents
  local docs   = text_loader.load_documents(spec.source_files)
  local tokens = tokenizer.tokenize_documents(docs)

  -- 2. Invariants (core LiteratureHero layer)
  local inv_results = invariant_registry.evaluate_all(tokens, spec)
  local graph       = invariant_graph.build(inv_results)
  local risk_score  = invariant_graph.aggregate_risk(graph)
  local institutions = institutional_recs.from_invariants(inv_results, graph, spec)

  -- 3. Build a shared analysis context for higher-level modules
  local ctx = {
    spec        = spec,
    docs        = docs,
    tokens      = tokens,
    invariants  = inv_results,
    invariant_graph = graph,
    risk_score  = risk_score,
    institutional_design = institutions
  }

  -- 4. Optional: hoax and faction analysis (if modules exist)
  if hoax_detector and hoax_detector.scan then
    ctx.hoax = hoax_detector.scan(ctx)
  end

  if faction_analyzer and faction_analyzer.scan then
    ctx.factions = faction_analyzer.scan(ctx)
  end

  -- 5. Optional: risk scoring, indicators, and education outputs
  if risk_scorer and risk_scorer.score then
    ctx.risk_indices = risk_scorer.score(ctx)
  end

  if indicator_builder and indicator_builder.build then
    ctx.indicators = indicator_builder.build(ctx)
  end

  if education_builder and education_builder.build then
    ctx.education = education_builder.build(ctx)
  end

  -- 6. Return a single, unified analysis result table
  ctx.meta = {
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  }

  return ctx
end

return lh_engine
