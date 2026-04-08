# LiteratureHero Lua Conflict Analysis Framework  
### Dependency‑Free Societal‑Collapse Pattern Detection and Prevention Design

## 1. Core Objectives and Scope

This framework defines a self‑contained Lua ecosystem for analyzing conflict scenarios across fictional works (e.g., ATOM RPG–style post‑apocalyptic narratives) and real‑world documents describing crises, near‑misses, and institutional failures.  It aims to identify recurring narrative and structural patterns that precede societal collapse, map them onto a set of 20+ invariants (such as Unity/Hive Mind, Tech Gatekeeping, and Doomsday Prophecy), and translate those patterns into practical prevention insights for institutions, monitoring systems, and public education. [magnvsrpgjourney.substack](https://magnvsrpgjourney.substack.com/p/atom-rpg-a-fallout-esque-post-soviet)

The system must run purely within Lua with no external NLP or ML libraries, relying on custom tokenization, heuristic semantic analysis, pattern grammars, and narrative-structure parsing. It analyses texts via a modular pipeline: ingestion, normalization, invariant detection, hoax/meta‑narrative structure detection, faction/faction comparison, and multi‑axis risk scoring. Outputs are designed to produce: (1) institutional design recommendations, (2) early‑warning indicators and dashboards, and (3) educational narratives and summaries understandable by non‑experts.

The framework is intentionally GitHub‑oriented: all modules are small, well‑documented Lua files, with a clear directory structure, test files, and CLI entrypoints, so that other researchers can fork, extend invariants, and integrate with their own data sources.

***

## 2. Repository Layout and File Organization

This section describes the proposed directory structure and file responsibilities to keep the project maintainable and extendable.

Suggested top‑level layout:

```text
literaturehero/
  README.md
  LICENSE
  docs/
    architecture/
      literaturehero_lua_framework.md
    invariants/
      invariant_catalog.md
      invariant_design_notes.md
    usage/
      cli_guide.md
      integration_patterns.md
  src/
    core/
      lh_engine.lua
      lh_pipeline.lua
      lh_text_loader.lua
      lh_tokenizer.lua
      lh_normalizer.lua
      lh_narrative_parser.lua
      lh_pattern_lang.lua
    invariants/
      invariant_base.lua
      invariant_unity_hivemind.lua
      invariant_tech_gatekeeping.lua
      invariant_doomsday_prophecy.lua
      ... (other invariant modules)
    analysis/
      lh_hoax_detector.lua
      lh_faction_analyzer.lua
      lh_risk_scorer.lua
      lh_recommender.lua
      lh_indicator_builder.lua
      lh_education_builder.lua
    cli/
      lh_cli.lua
      lh_batch_analyze.lua
  tests/
    test_tokenizer.lua
    test_invariants.lua
    test_risk_scorer.lua
    test_pipeline.lua
```

Each module is required to be self‑contained and avoid non‑Lua dependencies, ensuring portability to environments where only a Lua interpreter is available (game engines, minimal servers, air‑gapped research machines).

***

## 3. Text Processing Pipeline

The pipeline structures how raw documents are processed into structured risk and recommendation outputs. It is designed as a sequence of small, composable steps that can be run independently or chained.

### 3.1. High‑Level Pipeline Stages

1. **Text Loading (`lh_text_loader.lua`)**  
   This module loads text from different sources: local files, stdin, embedded content, or pre‑provided strings. It provides a uniform text‑document abstraction that includes metadata (source name, date, genre, fictional vs. real, language hints) that can be used for weighting in later stages.

2. **Normalization and Cleaning (`lh_normalizer.lua`)**  
   This stage standardizes whitespace, normalizes punctuation, handles quotes, splits into logical paragraphs, and optionally performs simple case folding while preserving original text for reference. It can also identify likely section headings, timestamps, and enumerated lists via pattern matching.

3. **Tokenization (`lh_tokenizer.lua`)**  
   A custom tokenization routine transforms normalized text into token streams. Rather than implementing full morphological parsing, it focuses on robust splitting (words, numbers, punctuation), sentence boundary detection using heuristic rules, and optional phrase chunking based on punctuation and conjunction patterns.

4. **Narrative Structure Parsing (`lh_narrative_parser.lua`)**  
   Using sentence and paragraph boundaries plus simple cue words, this module identifies approximate narrative roles: setting/background, rising tension, climax, and aftermath/resolution. It also attempts to mark important actors (factions), their stated goals, and key events that change the balance of power or social cohesion.

5. **Invariant Detection (`src/invariants/*`)**  
   Each invariant is implemented as a Lua module exposing a standard interface (`scan(doc_ctx)`), consuming tokens, narrative segments, and actor graphs to produce a score and evidence snippets. The invariant layer acts as the main analytical engine for identifying collapse‑related patterns.

6. **Hoax / Meta‑Narrative Detection (`lh_hoax_detector.lua`)**  
   This module searches for patterns related to deliberate misinformation, conspiratorial framing, and “hoax” structures (such as hidden puppeteers, secret plots, and scapegoating narratives) that often amplify conflict and destabilization.

7. **Faction Analysis (`lh_faction_analyzer.lua`)**  
   Based on actor mentions, pronoun clusters, and identity markers, this module constructs a coarse graph of factions, their perceived grievances, alliances, and asymmetries (like tech access or narrative control). It links factions to activated invariants.

8. **Risk Scoring (`lh_risk_scorer.lua`)**  
   The risk scorer aggregates invariant outputs and faction dynamics into multi‑dimensional risk scores (e.g., cohesion risk, governance risk, tech‑asymmetry risk, escalation probability). It tracks intensity, breadth across the narrative, and whether patterns resolve or remain unresolved.

9. **Output Generation (`lh_recommender.lua`, `lh_indicator_builder.lua`, `lh_education_builder.lua`)**  
   These modules transform analysis results into three aligned outputs: policy recommendations, early‑warning indicators, and educational text suitable for public understanding and training materials.

10. **CLI Integration (`cli/lh_cli.lua`)**  
    A simple command‑line interface allows users to process one or many documents and select output modes (JSON, markdown reports, summary only, etc.), making the framework suitable for automated pipelines and GitHub Actions workflows.

***

## 4. Custom Linguistic Foundations (Dependency‑Free NLP)

This section outlines how to implement internal linguistic analysis without external libraries.

### 4.1. Tokenization Strategy

`lh_tokenizer.lua` should implement a few key capabilities:

- Sentence boundary detection based on punctuation (`.`, `?`, `!`), capitalization of next token, and line breaks, with limited exceptions for abbreviations (configurable).
- Word tokenization by splitting on whitespace and punctuation, preserving punctuation as separate tokens when useful (e.g., `"`, `:`, `;`, `—`).
- Numeric and time tokens recognized via patterns (e.g., years, dates, counts) which can matter for escalation timelines.
- Phrase detection by grouping tokens between commas and conjunctions (`and`, `or`, `but`, `however`) to approximate clauses that describe actors and actions.

The tokenizer should expose a simple structure:

```lua
local tokenizer = {}

function tokenizer.tokenize(text)
  -- returns { sentences = { { tokens = {...} }, ... }, raw = text }
end

return tokenizer
```

### 4.2. Semantic Pattern Recognition Without ML

Instead of probabilistic models, semantic recognition relies on:

- Curated keyword sets and phrase templates per invariant.
- Small rule‑based “pattern grammars” (implemented in `lh_pattern_lang.lua`) that express expressions like “actor A threatens actor B with outcome C” using regular expressions and token proximity rules.
- Heuristics that detect intensifiers (`inevitable`, `total`, `final`, `extermination`), conditional markers (`if`, `unless`, `otherwise`), and prophecy markers (`will`, `destined`, `foretold`, `prophesied`, `cannot be avoided`).

`lh_pattern_lang.lua` should provide helper functions:

```lua
-- Match any of several words within N tokens.
pattern.near(tokens, index, word_list, window)

-- Match a phrase pattern “X of Y” or “Y must X”.
pattern.match_phrase(tokens, start_idx, templates)
```

This minimal DSL lets invariants be articulated as readable rule sets rather than hard‑coded nested conditionals.

### 4.3. Narrative Structure Parsing

`lh_narrative_parser.lua` should approximate traditional narrative arcs:

- Identify early sections with high density of setting cues (place names, time markers, general descriptions) as the “setup”.
- Track growth in conflictual verbs and negative sentiment phrases to detect “rising tension”.
- Mark the region with maximal conflict density and decisive events as “climax”.
- Analyze whether the resolution region shows reconciliation, stable new institutions, or unresolved hostility.

For games like ATOM RPG and similar post‑war depictions, narrative segments often show:

- Collapse as historical fact (opening exposition).
- Competing factions attempting to control resources or narratives in the aftermath. [tvtropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/AtomRPG)

The parser should export a structure like:

```lua
doc_ctx.narrative = {
  segments = {
    { role = "setup", start_sentence = 1, end_sentence = 20 },
    { role = "rising_conflict", start_sentence = 21, end_sentence = 80 },
    { role = "climax", start_sentence = 81, end_sentence = 110 },
    { role = "aftermath", start_sentence = 111, end_sentence = 150 }
  }
}
```

***

## 5. Invariant System Design

The invariant system encodes recurring collapse‑relevant patterns found in fiction and history. It must be easy to extend and parameterize.

### 5.1. Invariant Interface

Each invariant module (e.g., `invariant_tech_gatekeeping.lua`) should implement a standard interface:

```lua
local invariant = {}

invariant.id = "TECH_GATEKEEPING"
invariant.label = "Tech Gatekeeping"
invariant.description = "Control of critical technology by a closed group..."

-- Configuration for rule sets, keywords, and thresholds.
invariant.config = {
  key_terms = { "technology", "machine", "reactor", "encryption", "weapons" },
  control_terms = { "forbidden", "restricted", "classified", "elite", "priesthood" },
  exclusion_terms = { "public access", "open source" }
}

-- scan(doc_ctx) -> {score, evidence, segments}
function invariant.scan(doc_ctx)
  -- Analyze tokens, narrative segments, and factions.
  -- Return a numeric score and evidence snippets.
end

return invariant
```

The engine (`lh_engine.lua`) loads all invariant modules dynamically and passes a shared `doc_ctx` that includes:

- Tokens and sentences.
- Narrative segments.
- Actor/faction graph.
- Hoax/meta‑narrative markers.
- Document metadata (fiction/real, type, time period).

### 5.2. Example Invariant: Unity / Hive Mind

**Concept:** Society or a key faction is gradually or suddenly forced into a single voice, suppressing dissent and individuality, often framed as necessary for survival.

Detection heuristics:

- High frequency of terms like “unity”, “harmony”, “one mind”, “collective will”, “the people speak as one”.
- Co‑occurrence with suppression markers: “traitor”, “heretic”, “enemy of the people”, “purge”.
- Narrative structure where dissenting voices disappear or are punished as the story progresses.

Implementation outline in `invariant_unity_hivemind.lua`:

- Scan for phrases implying mandatory unity near enforcement verbs.
- Track whether actor diversity (number of distinct factions or viewpoints) declines over the narrative.
- Score proportionally to how integral unity enforcement is to the climax and aftermath segments.

### 5.3. Example Invariant: Tech Gatekeeping

**Concept:** Critical technologies are controlled exclusively by a limited group, creating dependency, power asymmetries, and black‑market or insurgent responses.

Detection heuristics:

- Technology nouns near ownership markers like “only we”, “the Order”, “the scientists”, “the vault”, and limitation terms like “forbidden”, “restricted”.
- Factions described as “backwards”, “primitive”, or “in the dark” contrasted with a small group “in the know”.
- Events where access to tech is traded for loyalty or used as leverage.

The invariant module:

- Uses pattern language to detect gatekeeping statements.
- Connects technology mentions to factions via nearby proper nouns and pronouns.
- Raises risk when tech gatekeeping co‑occurs with other invariants such as Doomsday Prophecy or Hoax structures that justify keeping knowledge secret.

### 5.4. Example Invariant: Doomsday Prophecy

**Concept:** An explicitly articulated prophecy, prediction, or inevitability narrative that frames collapse or apocalyptic conflict as unavoidable, often used to justify extreme measures.

Detection heuristics:

- Prophecy terms: “prophecy”, “vision”, “foretold”, “oracle”, “divination”, “scripture”.
- Inevitability language: “cannot be stopped”, “inevitable”, “our fate”, “destined to burn”.
- Systematic linking of present actions to an inevitable catastrophic future used as moral cover for atrocities or preemptive violence.

Implementation details:

- Identify prophecy sections using keywords and pattern language.
- Measure how strongly the narrative aligns with the prophecy (do actors act “because the prophecy says so”?).
- Score higher if prophecy is cited explicitly as justification for escalations, purges, or war.

### 5.5. Invariant Catalog

`docs/invariants/invariant_catalog.md` should maintain a table of invariants, with fields such as:

| ID                    | Name                | Typical Triggers                                | Collapse Link                                   |
|-----------------------|---------------------|-------------------------------------------------|------------------------------------------------|
| UNITY_HIVEMIND        | Unity / Hive Mind   | Forced unanimity, suppression of dissent        | Eliminates self‑correction, increases fragility |
| TECH_GATEKEEPING      | Tech Gatekeeping    | Closed control of vital technology              | Creates brittle hierarchies and resentment      |
| DOOMSDAY_PROPHECY     | Doomsday Prophecy   | Inevitability narratives justifying extremism   | Normalizes catastrophic risk‑taking             |

This catalog supports systematic extension and consistent use across modules.

***

## 6. Hoax and Meta‑Narrative Structure Detection

Hoax structures often appear as stories about stories: secret plots, hidden puppet masters, and “true” narratives that reinterpret all evidence. `lh_hoax_detector.lua` focuses on identifying these meta‑structures.

Detection principles:

- Recurrent claims of concealed truth vs. official lies, using terms like “hoax”, “fabricated”, “fake”, “puppet”, “behind the scenes”.
- Simplistic causality with a single hidden villain or group responsible for all complex problems.
- Evidence of pattern over‑generalization: “they control everything”, “nothing happens without them”.
- Accusations that opposition is blind, brainwashed, or corrupted for not accepting the “real” story.

Implementation:

- Use keyword clusters and pattern language to mark likely hoax segments.
- Link hoax segments to involved factions or actors (propagandists vs. targets).
- Provide an output structure with specific passages and a confidence score, which downstream modules use to adjust risk and recommendations.

***

## 7. Faction Analysis and Actor Graph

`lh_faction_analyzer.lua` builds a simple actor/faction graph by:

- Identifying candidate faction names (capitalized multi‑word phrases, named groups like “Brotherhood”, “Council”, “Order”, “Party”).
- Tracking pronoun references over sentences to group mentions into persistent entities.
- Attaching narrative attributes such as goals, grievances, control of resources, and tech gatekeeping status.

The resulting data structure might include:

```lua
doc_ctx.factions = {
  {
    id = "FACTION_ORDER",
    names = { "The Order" },
    roles = { "ruling_elite" },
    capabilities = { "tech_gatekeeping", "narrative_control" },
    grievances = {},
    alliances = { "FACTION_SECURITY_FORCES" },
  },
  ...
}
```

The analyzer also identifies:

- Asymmetries (who has weapons, information, and legitimacy).
- Whether factions are portrayed as redeemable, inherently evil, or simply misaligned.
- Shifts in relative power over narrative segments, which contribute to dynamic risk scoring.

***

## 8. Risk Scoring Model

`lh_risk_scorer.lua` aggregates invariant signals and faction relationships into structured risk scores. The goal is not precise prediction, but comparative assessment across texts and time.

### 8.1. Dimensions of Risk

At minimum, define these axes:

- **Cohesion Risk:** High when UNITY_HIVEMIND, hoax narratives, scapegoating, or systematic dehumanization are present.
- **Governance Risk:** High when institutions appear brittle, corrupt, or non‑responsive, especially when paired with prophecy or coup narratives.
- **Tech Asymmetry Risk:** Driven by TECH_GATEKEEPING and similar invariants indicating concentrated control of critical infrastructure.
- **Escalation Risk:** Derived from the density and severity of conflict events, revenge cycles, and justifications for preemptive violence.
- **Resilience / Recovery Indicators:** Positive signals where narratives show inclusive reforms, power‑sharing, or transparent institutions mitigating tensions.

Each dimension can be scored on 0‑100 scale, computed from weighted invariant scores and narrative context. Fictions like ATOM RPG provide examples of “end state” collapses, while real‑world documents give partial, messy trajectories; the scoring model should accommodate both.

### 8.2. Temporal and Segment‑Based Analysis

Risk should be calculated per narrative segment and then aggregated:

- Segment‑level scores identify when and how risk emerges or drops.
- Aggregate scores help evaluate whether a text overall encourages or discourages collapse‑enabling patterns.

***

## 9. Prevention‑Oriented Outputs

The framework’s outputs are explicitly prevention‑focused and must serve three audiences: policymakers, crisis monitors, and the general public.

### 9.1. Institutional Design Recommendations (`lh_recommender.lua`)

This module translates invariants and risk patterns into structural recommendations. Examples:

- Strong UNITY_HIVEMIND signals combined with hoax narratives might yield recommendations for protecting pluralistic media ecosystems, enforcing transparency in decision‑making, and safeguarding whistleblower channels.
- TECH_GATEKEEPING in pivotal institutions could lead to recommendations around open protocols, distributed control of critical systems, and redundancy to prevent catastrophic single‑point failure.
- DOOMSDAY_PROPHECY prevalence can prompt guidelines for vetting apocalyptic rhetoric in public communication, encouraging counter‑narratives that emphasize reversible choices and non‑fatalism.

The module should output a structured Lua table (or JSON when serialized):

```lua
{
  recommendations = {
    {
      category = "Institutional Design",
      invariant_ids = { "TECH_GATEKEEPING", "UNITY_HIVEMIND" },
      summary = "Distribute authority over critical technologies...",
      rationale = "Detected patterns of closed technocratic control..."
    },
    ...
  }
}
```

### 9.2. Early‑Warning Indicators (`lh_indicator_builder.lua`)

The indicator builder constructs machine‑readable early‑warning signals suitable for dashboards or monitoring systems:

- For each invariant, define a set of observable textual signals that can be tracked over time in news feeds, speeches, and policy documents.
- Convert these into indicator definitions with thresholds and suggested response actions.
- Provide a minimal JSON schema for integration into external monitoring tools.

Example:

```lua
{
  indicators = {
    {
      id = "EWI_TECH_GATEKEEPING_PUBLIC_DISCOURSE",
      description = "Rising emphasis on restricting public access to critical technology.",
      linked_invariants = { "TECH_GATEKEEPING" },
      metric = "normalized frequency per 10k words",
      alert_threshold = 0.8
    }
  }
}
```

### 9.3. Educational Materials (`lh_education_builder.lua`)

This module generates accessible explanations aimed at students, journalists, and general audiences:

- Plain‑language descriptions of each invariant with concrete examples from anonymized or fictional scenarios.
- Short narratives demonstrating how early interventions could have altered trajectories.
- Visualizable structures (e.g., simple ASCII “graphs” of factions and their relationships) to make complex dynamics legible.

The educational output should be suitable for inclusion in GitHub pages, wiki documentation, or teaching materials.

***

## 10. CLI and Usage Patterns

`cli/lh_cli.lua` provides a simple interface:

```bash
lua cli/lh_cli.lua analyze --input path/to/text.txt --mode full
lua cli/lh_cli.lua analyze --input path/to/text.txt --output report.md
lua cli/lh_cli.lua batch --input-dir corpus/ --json
```

Modes can include:

- `invariants-only`: list invariants detected with scores.
- `risk-summary`: produce risk scores without detailed evidence.
- `policy-report`: output a markdown report summarizing risks and recommendations.
- `education`: generate educational text explaining the patterns in the document.

CLI scripts should be thin wrappers around `lh_pipeline.lua`, which wires modules together.

***

## 11. Example Lua Skeletons

Below is a minimal but concrete Lua skeleton for the core engine and one invariant; these are intentionally lightweight and dependency‑free.

**Filename:** `src/core/lh_engine.lua`  
**Destination:** `src/core/`

```lua
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
```

**Filename:** `src/invariants/invariant_unity_hivemind.lua`  
**Destination:** `src/invariants/`

```lua
-- Unity / Hive Mind invariant

local pattern = require("src.core.lh_pattern_lang")

local invariant = {}

invariant.id = "UNITY_HIVEMIND"
invariant.label = "Unity / Hive Mind"
invariant.description = "Forced or coercive unity that suppresses dissent and diversity."

local unity_terms = {
  "unity", "one mind", "single will", "collective", "harmony",
  "united forever", "speak as one"
}

local suppression_terms = {
  "traitor", "heretic", "enemy of the people", "purge",
  "cleansing", "eradicate", "silence"
}

function invariant.scan(doc_ctx)
  local tokens = doc_ctx.tokens
  local evidence = {}
  local score = 0

  for s_idx, sent in ipairs(tokens.sentences or {}) do
    for t_idx, tok in ipairs(sent.tokens or {}) do
      if pattern.contains_phrase(sent, unity_terms) then
        if pattern.near(sent.tokens, t_idx, suppression_terms, 8) then
          score = score + 2
          table.insert(evidence, {
            sentence_index = s_idx,
            text = table.concat(sent.tokens, " ")
          })
          break
        else
          score = score + 1
        end
      end
    end
  end

  -- Scale score by narrative context (e.g., high weight in climax/aftermath)
  if doc_ctx.narrative and doc_ctx.narrative.segments then
    for _, seg in ipairs(doc_ctx.narrative.segments) do
      if seg.role == "climax" or seg.role == "aftermath" then
        -- naive scaling: if many evidence sentences in these segments, boost
        for _, ev in ipairs(evidence) do
          if ev.sentence_index >= seg.start_sentence
            and ev.sentence_index <= seg.end_sentence then
            score = score + 1
          end
        end
      end
    end
  end

  return {
    id = invariant.id,
    label = invariant.label,
    score = score,
    evidence = evidence
  }
end

return invariant
```

These skeletons can be extended with more robust logic, but they already illustrate how to keep modules independent and rule‑based.
