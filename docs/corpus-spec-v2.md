# GESP Discourse Corpus v2.0 Specification

This document specifies the v2.0 schema, organization, and annotation protocol for the LiteratureHero GESP discourse corpus. It defines how claim types, false analogies, GESP stress, distortion vectors (ΔD), and discourse-stress (dD) are stored and versioned, so that all Lua tools, validation harnesses, and debunking documents share a stable data backbone.

The corpus is designed to support:

- Claim-type and false-analogy analysis.  
- Dimension-level stress estimation (`s_claimed`, `s_estimated`) and distortion (ΔD).  
- Doom vs agency discourse analysis (dD).  
- Gold-standard evaluation for the Lua analysis stack and future ML models.

***

## 1. High-Level Design and Organization

### 1.1 Primary indexing axes

The corpus is explicitly organized around four analytical axes:

1. **Claim type** (primary axis)  
   - Single-Factor Doom  
   - Conspiracy-Driven  
   - Moral Panic  
   - Everything-Is-Broken  
   - Scholarly Risk  

2. **Domain / source type**  
   - Fiction  
   - News / longform  
   - Social / discussion  

3. **False-analogy pattern(s)**  
   - e.g., “Single Shock = Total Collapse”, “Every Crisis Is Rome”, “Local Failure = Global Collapse”, “Violence Equals Collapse”, “Tech Collapse = Preindustrial Desert”, “Information Chaos = Immediate Regime Fall”, etc.

4. **Doom/agency orientation**  
   - Doom-dominant  
   - Balanced  
   - Agency-dominant  

Each corpus record encodes all four axes, so you can:

- Sample by claim type × domain.  
- Analyze how specific false analogies distort particular dimensions.  
- Study how doom-heavy vs agency-heavy language affects ΔD and dD.

### 1.2 Directory layout

All data files for this corpus live under:

- `data/gesp_discourse_corpus/`

Recommended top-level files and subdirectories:

- `data/gesp_discourse_corpus/schema.json` – machine-readable schema.  
- `data/gesp_discourse_corpus/fiction_samples.csv` – fiction snippets.  
- `data/gesp_discourse_corpus/news_samples.csv` – news / longform.  
- `data/gesp_discourse_corpus/social_samples.csv` – social / discussion.  
- `data/gesp_discourse_corpus/gold/` – gold-standard subsets.  
  - `gold_corpus_v2.csv` – main gold file.  
  - `gold_annotator_guidelines_v2.md` – annotation manual.  
- `data/gesp_discourse_corpus/README.md` – human overview and versioning notes.

Versioning convention:

- Each CSV includes a `schema_version` column and a `corpus_version` metadata line (e.g., in README or as a separate `metadata.json`), so tools can check compatibility.

***

## 2. Record Schema

Each snippet (row) in the main corpus files shares the same core schema. Columns are grouped by function.

### 2.1 Identity and context

- `id` (string)  
  Unique, stable identifier, e.g., `LH-FIC-000123`, `LH-NEWS-000057`, `LH-SOC-000412`.

- `schema_version` (string)  
  Schema version string, e.g., `v2.0.0`.

- `corpus_version` (string)  
  Corpus version string, e.g., `v2.0.0-alpha`, `v2.0.1`.

- `domain` (string)  
  One of: `fiction`, `news`, `social`, `historical`, `other`.

- `source_name` (string)  
  Human-readable source (e.g., novel title, outlet name, platform).

- `source_location` (string)  
  Location within source, e.g., `"Ch. 3, p. 45"`, `"2024-05-10 feature"`, `"thread-123, post-7"`.

- `language` (string)  
  ISO language code, e.g., `en`.

- `text` (string)  
  Raw snippet text (50–200 words recommended). For copyright-sensitive sources, this may be truncated, anonymized, or replaced with a hash plus a local data pointer.

- `context_meta` (JSON or stringified JSON)  
  Optional structured metadata, e.g., `{ "region": "US", "year": 2024, "topic": "climate" }`.

### 2.2 Claim typology and analogies

- `claim_type` (string or categorical)  
  Primary claim type, one of:  
  - `single_factor_doom`  
  - `conspiracy_driven`  
  - `moral_panic`  
  - `everything_is_broken`  
  - `scholarly_risk`

- `claim_type_secondary` (string, optional)  
  Secondary type if genuinely mixed; same enum as above.

- `false_analogy_tags` (stringified list)  
  Zero or more labels, e.g.,  
  `["single_shock_total_collapse","every_crisis_is_rome"]`.

- `focus_dimensions` (stringified list)  
  Primary dimensions named or implied in the claim, subset of `["G","E","S","P"]`.

- `scope` (string)  
  `local`, `regional`, `national`, `global`, or `unspecified`.

- `timeline` (string)  
  Free text or controlled tags, e.g., `months`, `years`, `decades`, `immediate`, `vague`.

### 2.3 Stress vectors and distortion ΔD

All stress scores are normalized to. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/aef90e02-9796-472e-9255-39634ffc81aa/G-E-S-P-Collapse-Framework-Validated-Expansion-Report.pdf)

- `s_claimed` (stringified JSON)  
  `{ "G": 0.3, "E": 0.8, "S": 0.7, "P": 0.5 }` – stress implied by the claim.

- `s_estimated` (stringified JSON)  
  `{ "G": 0.2, "E": 0.4, "S": 0.3, "P": 0.3 }` – best estimate from external indicators / expert synthesis for the context.

- `delta` (stringified JSON)  
  `{ "G": 0.1, "E": 0.4, "S": 0.4, "P": 0.2 }` – the distortion vector  
  \(\Delta_D = s_D^{\text{claimed}} - s_D^{\text{estimated}}\).

Optional: to support more fine-grained modeling, you may also include separate “D-layer” fields:

- `sD_claimed` (stringified JSON)  
- `sD_estimated` (stringified JSON)

These can hold perception-oriented scores if you decide to distinguish between structural and discursive stress.

### 2.4 Hex tagging and composite stress

- `hex_tag` (string)  
  Hex-encoded GESP state, `0xGESP`, four nibbles 0–15 each.  

  Example: `0x9BDE`.

- `vG`, `vE`, `vS`, `vP` (integer, optional)  
  Nibbles 0–15; redundant with `hex_tag` but useful for direct stats.

- `Ct` (float)  
  Composite collapse stress from the current model, including coupling terms if implemented.

- `Ct_baseline` (float, optional)  
  Baseline or reference composite stress for the context (used in Δ comparisons and modeling).

### 2.5 Doom/agency and dD

- `doom_agency_label` (string)  
  `doom_dominant`, `balanced`, or `agency_dominant`.

- `doom_counts` (stringified JSON)  
  `{ "G": 3, "E": 1, "S": 2, "P": 0 }` – per-dimension doom statements (approximate).

- `agency_counts` (stringified JSON)  
  `{ "G": 1, "E": 2, "S": 0, "P": 1 }` – per-dimension agency statements.

- `dD_overall` (float)  
  Overall discourse-stress ratio for the snippet.

- `dD_per_dim` (stringified JSON)  
  `{ "G": 0.75, "E": 0.33, "S": 1.0, "P": 0.0 }` – per-dimension dD values.

### 2.6 Historical/archetype mapping

- `case_family` (string)  
  Best-fit historical archetype, e.g., `rapid_shock_high_R`, `climate_cascade`, `elite_implosion`, `slow_hollowing`, `external_conquest`, `prolonged_fragility`.

- `historical_anchors` (stringified list, optional)  
  E.g., `["postwar_europe","rwanda_reconstruction"]`.

### 2.7 Reframing and interventions

- `reframed_assessment` (string)  
  Short, conditional summary: e.g.,  
  `"If current housing and wage trends continue, local S and E stress will likely rise, but policy levers X and Y can moderate risk over the next decade."`

- `intervention_levers` (stringified list)  
  `[{"dimension": "E", "action": "expand housing vouchers"},{"dimension": "S", "action": "support cross-neighborhood forums"}]`.

- `prompt_ids` (stringified list, optional)  
  IDs of conversation prompts from `docs/collapseconversationprompts.md` or prompt libraries that are recommended for this snippet.

### 2.8 GESP / hex tags and USR markers

- `hex_tag_extended` (string, optional)  
  Future-proof field if an I dimension or other extensions are adopted.

- `usr_tag` (string, optional)  
  Optional usefulness-score tag for the record, e.g., `0x9A` for high utility as an example.

### 2.9 Annotation metadata

- `annotator_id_primary` (string)  
  ID of the main annotator.

- `annotator_id_secondary` (string, optional)  
  ID of the second annotator in gold subsets.

- `annotation_method` (string)  
  E.g., `human_v2`, `lua_auto_v1`, `hybrid_v2`.

- `annotation_date` (string)  
  ISO 8601 timestamp, e.g., `2026-04-07T21:15:00Z`.

- `is_gold` (boolean)  
  `true` or `false`; true for records that are part of the gold-standard set.

- `disagreement_notes` (string, optional)  
  Free text description of where annotators disagreed and why (for gold entries).

***

## 3. Claim-Type × Domain Grid

To avoid a doom-skewed or type-skewed corpus, v2.0 targets a balanced grid.

### 3.1 Grid definition

Rows: claim types  
Columns: domains (fiction, news, social)

For each cell (claim type, domain):

- Target at least N snippets, where N can initially be 40–50.  
- Within each cell, aim for diversity across doom/agency orientation:
  - Doom-dominant  
  - Balanced  
  - Agency-dominant

Example grid cell:

- Claim type: `single_factor_doom`  
- Domain: `news`  
- Coverage:  
  - Doom-heavy op-eds claiming “X will collapse everything”.  
  - Balanced analyses that discuss serious risk but include options.  
  - Agency-oriented commentary that reframes the same stressors with policy levers.

### 3.2 Minimum v2.0 coverage targets

As an initial target (tunable):

- 200–500 fiction snippets.  
- 200–500 news/longform snippets.  
- 200–500 social/discussion snippets.

Within each domain:

- At least 40–50 snippets per claim type.  
- Within each claim type, at least 10–15 per major false-analogy pattern that applies.

***

## 4. False-Analogy Axis and Patterns

False analogies are treated as primary schema elements, not secondary labels.

### 4.1 Pattern records (conceptual)

Each false-analogy pattern should be defined in `docs/collapseclaimstypology.md` (and potentially mirrored in a small JSON file), with:

- `analogy_id` (string)  
  E.g., `rome_tomorrow`, `single_shock_total_collapse`, `local_equals_global`, `violence_equals_collapse`, `tech_collapse_preindustrial`, `info_chaos_regime_fall`.

- `source_domain` (string)  
  `historical`, `fictional_world`, or `mixed`.

- `source_label` (string)  
  Short descriptor, e.g., `"Late Roman Empire"`, `"The Road universe"`.

- `target_domain_hint` (string)  
  E.g., `current_US`, `global_climate`, `EU_politics`.

- `s_source` (stringified JSON)  
  Approximate GESP vector for the source case.

- `s_target_estimated_template` (stringified JSON)  
  Typical real-world stress pattern for contexts where the analogy is used.

- `analogy_notes` (string)  
  Comments on why this analogy tends to misfit (time compression, scope inflation, misaligned dimensions).

### 4.2 Linking patterns to snippets

In corpus rows:

- `false_analogy_tags` should contain one or more `analogy_id`s where applicable.  
- You may additionally include:
  - `analogy_distortion` (stringified JSON) for advanced uses, e.g.,  
    `{ "G": 0.1, "E": 0.4, "S": 0.3, "P": 0.2, "time": 0.8, "scope": 0.6 }`.

This explicit axis supports analysis like:

- “Conspiracy-driven + `info_chaos_regime_fall` patterns exaggerate P and S and compress timelines.”  
- “Moral panic + `violence_equals_collapse` distort S and P relative to G and E.”

***

## 5. Gold Subset Protocol

The gold subset provides human-annotated ground truth for validation and calibration.

### 5.1 Size and sampling

- Target size: ~200 gold snippets for v2.0.  
- Sampling strategy:
  - Cover all five claim types.  
  - Cover all three domains.  
  - Include multiple false-analogy patterns.  
  - Intentionally include ambiguous and edge cases.

Gold snippets should be drawn from the main corpus; gold status is indicated via `is_gold = true`.

### 5.2 Double annotation

For each gold record:

- At least two independent annotators provide values for:
  - `claim_type` (and secondary if present).  
  - `false_analogy_tags`.  
  - `s_claimed`.  
  - `s_estimated`.  
  - `doom_agency_label`, `dD_overall`, `dD_per_dim`.  
  - `case_family`.  
  - `reframed_assessment`.  
  - `intervention_levers`.  
  - `hex_tag`.

Storage options:

- Option A: store consensus values in the main fields and annotator-specific values in separate columns, e.g.,  
  - `claim_type_a`, `claim_type_b`  
  - `s_claimed_a`, `s_claimed_b`  
  - etc.  

- Option B: maintain separate gold-annotation files keyed by `id`, merged via tooling.

In either case, `annotator_id_primary` and `annotator_id_secondary` identify the raters.

### 5.3 Inter-annotator agreement (IAA)

For the gold subset, compute and track:

- Claim type agreement (e.g., Cohen’s kappa) on `claim_type`.  
- Multi-label agreement on `false_analogy_tags` and `focus_dimensions` (e.g., Jaccard similarity or alpha).  
- Mean absolute difference in `s_claimed` and `s_estimated` per dimension.  
- Agreement on `doom_agency_label`.  
- Correlation or agreement in `dD_overall` (treated as ordinal or numeric).

Disagreements:

- Summarize key disagreement patterns in `disagreement_notes`:
  - Which fields diverged.  
  - Rater rationales.  
  - Any resolution or guideline change recommended.

Guideline updates:

- Use recurring disagreements to refine `gold_annotator_guidelines_v2.md`.  
- For example, clarify boundaries between `everything_is_broken` vs `moral_panic`, or between doom-dominant and balanced.

***

## 6. File Naming and Versioning Conventions

### 6.1 Core corpus files

Recommended names:

- `data/gesp_discourse_corpus/fiction_v2.csv`  
- `data/gesp_discourse_corpus/news_v2.csv`  
- `data/gesp_discourse_corpus/social_v2.csv`  

Each row adheres to the schema above.  

`schema.json` should define:

- Fields, types, allowed values, and optional/required flags.  
- Version `v2.0.0` and a short description.

### 6.2 Gold subset

- Directory: `data/gesp_discourse_corpus/gold/`  
- Main file: `gold_corpus_v2.csv`  
  - Contains all gold entries (possibly merged across domains).  
- Guideline file: `gold_annotator_guidelines_v2.md`  
  - Contains detailed instructions, examples, and decision rules.

Optional:

- `gold_iaa_metrics_v2.json` for storing computed IAA stats.

### 6.3 Versioning and changes

When updating the schema:

- Increment `schema_version`.  
- Document changes in `README.md` and/or a `CHANGELOG.md`.

When updating the corpus:

- Increment `corpus_version`.  
- Record:
  - New snippets added.  
  - Annotation fixes.  
  - Any re-labeling (with reasons).

***

## 7. Integration Points

This spec is designed to integrate cleanly with:

- `models/collapseriskmodel.lua`  
  - Consumes `s_claimed`, `hex_tag`, `s_estimated`, and computes `Ct` and ΔD.

- `src/gesp_discourse_analyzer.lua`  
  - Consumes `text` and optionally context to estimate `s_claimed`, `doom_counts`, `agency_counts`, and dD.  
  - Outputs can be compared against corpus annotations for validation.

- `src/gesp_debias_analyzer.lua` (or equivalent)  
  - Uses corpus `s_estimated` to evaluate claims and generate explanations.

- `docs/debunking-playbook-v2.md`  
  - References real snippets by `id`, using their claim types, analogy tags, ΔD, dD, and reframed assessments as worked examples.

By pinning all these components to a shared, explicit schema, LiteratureHero can evolve the analytical models and playbooks without losing alignment between data, code, and documentation.

***

## 8. USR and G/E/S/P Coverage

This schema is designed to:

- **Geo (G):** Capture environmental and infrastructural stress and its exaggeration.  
- **Eco (E):** Track economic stress narratives vs indicator-based baselines.  
- **Social (S):** Represent social cohesion, conflict, and moral panic dynamics.  
- **Political (P):** Model governance, legitimacy, and conspiracy framing.

USR tag for this spec: **0x9C** (very high research and integration usefulness).
