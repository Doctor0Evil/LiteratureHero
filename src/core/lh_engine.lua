-- Core LiteratureHero analysis engine (dependency-free)

local text_loader      = require("src.core.lh_text_loader")
local normalizer       = require("src.core.lh_normalizer")
local tokenizer        = require("src.core.lh_tokenizer")
local narrative_parser = require("src.core.lh_narrative_parser")
local hoax_detector    = require("src.analysis.lh_hoax_detector")
local faction_analyzer = require("src.analysis.lh_faction_analyzer")
local risk_scorer      = require("src.analysis.lh_risk_scorer")
local recommender      = require("src.analysis.lh_recommender")
local indicator_builder = require("src.analysis.lh_indicator_builder")
local education_builder = require("src.analysis.lh_education_builder")

local invariants = {
  require("src.invariants.invariant_unity_hivemind"),
  require("src.invariants.invariant_tech_gatekeeping"),
  require("src.invariants.invariant_doomsday_prophecy"),
  -- add more invariants here
}

local engine = {}

function engine.analyze(input_spec, opts)
  opts = opts or {}

  local doc = text_loader.load(input_spec)
  local norm_doc = normalizer.normalize(doc)
  local tokens = tokenizer.tokenize(norm_doc.text)
  local narrative = narrative_parser.parse(tokens)

  local doc_ctx = {
    raw = doc,
    norm = norm_doc,
    tokens = tokens,
    narrative = narrative
  }

  doc_ctx.hoax = hoax_detector.scan(doc_ctx)
  doc_ctx.factions = faction_analyzer.scan(doc_ctx)

  doc_ctx.invariants = {}
  for _, inv in ipairs(invariants) do
    local res = inv.scan(doc_ctx)
    doc_ctx.invariants[inv.id] = res
  end

  doc_ctx.risk = risk_scorer.score(doc_ctx)
  doc_ctx.recommendations = recommender.build(doc_ctx)
  doc_ctx.indicators = indicator_builder.build(doc_ctx)
  doc_ctx.education = education_builder.build(doc_ctx)

  return doc_ctx
end

return engine
