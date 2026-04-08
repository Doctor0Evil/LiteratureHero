# LiteratureHero Toolchain Architecture

This document describes the v2.0 toolchain architecture for LiteratureHero, from corpus ingestion through Lua analyzers and validation, into debunking playbooks, prompts, and risk models. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

***

## 1. High-level dataflow (text diagram)

At a high level, data moves through the system as follows. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

```
Raw texts (fiction / news / social)
        │
        ▼
  GESP Discourse Corpus
  (main table + gold subset)
        │
        │  (batched records: id, text, context, labels)
        ▼
  Lua Analyzers
  - src/gespdiscourseanalyzer.lua
  - src/gespdebiasanalyzer.lua
  - models/collapseriskmodel.lua
        │
        │  (features, s^claimed_D, hextag, d, d_D, D, patterns)
        ▼
  Validation Harness
  - src/gespvalidationharness.lua
        │
        │  (metrics, error costs, logs)
        ├───────────────► Risk Models & Ct/R dynamics
        │                  (docs/nonlinearctexamples.md, model code)
        │
        ▼
  Debunking Pipeline & Playbooks
  - docs/debunking-pipeline.md
  - docs/debunking-playbook-v2.md
        │
        │  (reframed assessments, levers)
        ▼
  Prompt Libraries & Front-Ends
  - prompts/*.json
  - UIs for organizers / educators / moderators
```

All modules share a common claim-level schema and metric definitions, enabling auditable end-to-end traces from narrative fragment to prevention-oriented prompts. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 2. Corpus layer

### 2.1 GESP discourse corpus

**Module:** GESP Discourse Corpus v2.0  
**Spec:** `docs/corpus-spec-v2.md`  
**Primary files:** `data/gesp_discourse_corpus.*` (CSV/JSONL/Parquet) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

The corpus is the empirical foundation for calibration, validation, and playbook examples. It holds snippets from fiction, news, and social media prioritized for collapse claim-type and false-analogy coverage rather than genre representativeness. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Each row implements the shared claim schema: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- `id`: stable unique ID.  
- `text`: raw snippet (or pointer/hash).  
- `context_source`: channel (fiction, news, social, other).  
- `context_meta`: JSON metadata (genre, work title, author, date, location, language). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Analytical labels and features:  

- `claimtype`: one or more of Single-Factor Doom, Conspiracy-Driven Collapse, Moral Panic, Everything-Is-Broken, Scholarly Risk. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `analogytags`: false-analogy tags (e.g., Single Shock Total Collapse, Every Crisis Is Rome). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `primarydimensions`: subset of {G,E,S,P} the claim is explicitly about. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `scope`: local, national, global, or system-specific.  
- `timeline`: rough horizon (months, years, decades, vague). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Stress vectors and derived fields:  

- `sclaimed`: JSON {G,E,S,P} – stress implied by the text. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `sestimated`: JSON {G,E,S,P} – estimated stress based on indicators or expert synthesis. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `delta` (or `D`): JSON {G,E,S,P} – distortion vector, sclaimed − sestimated. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `doomcounts`: JSON {G,E,S,P}: ND,doom. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `agencycounts`: JSON {G,E,S,P}: ND,agency. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `dD`: JSON {G,E,S,P} – per-dimension discourse-stress ratios; optionally overall `d`. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `hextag`: hex-encoded nibble tag 0xGESP. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `gespflags`: optional JSON for flags like high-stress-but-high-resilience or near-tipping. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Debunking and intervention fields:  

- `casefamily`: best-fit GESP case-family archetype (e.g., Rapid shock with low resilience, Long slow hollowing). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `reframedassessment`: structured Clarify–Measure–Contextualize–Reframe summary. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `interventionlevers`: JSON list of {dimension, action} pairs. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `promptsuggestions`: references into prompt libraries. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

### 2.2 Gold subset protocol

**Module:** Gold subset and IAA  
**Spec:** `docs/corpus-spec-v2.md` (Section: Gold subset protocol) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

A ~200-item gold subset is double-annotated for all key fields: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- `isgold`: boolean.  
- Duplicated fields per annotator (`claimtype_a`, `claimtype_b`, etc.).  
- `disagreementnotes`: free-text rationale and guideline corrections. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

The gold subset is the canonical testbed for Lua analyzer validation and inter-annotator agreement (kappa/alpha, MAE on sclaimed/sestimated, and agreement on doom/agency and dD). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 3. Lua analyzer layer

### 3.1 Core stress and discourse analyzer

**Module:** GESP Discourse Analyzer  
**File:** `src/gespdiscourseanalyzer.lua` [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Purpose: map raw text to lexical features, normalized stress estimates sclaimed, and global discourse-stress d. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Key components: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- Tokenization: basic whitespace/token splitting on lowercase text.  
- Lexicons: configurable geo/eco/social/political, doom, agency lists; loaded from config. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `extractfeatures(text)`: counts Graw, Eraw, Sraw, Praw, Dnegraw, Dposraw and total length. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `normalizeindicator(raw, length, context)`: hook into canonical normalization (from GESP risk model) to map counts into sD ∈. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `computestress(features)`: returns stress = {G,E,S,P} in. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `collapserisk(stress, weights, alpha)`: computes a composite risk scalar from stress; default weights and non-linearity parameter α are configurable. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `discoursestress(features)`: computes global dD = Dneg / (Dneg + Dpos + ε) plus raw counts. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `labeldiscoursed(d, bands)`: qualitative labels (agency-leaning, mixed, doom-leaning) based on empirical bands. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `relativepatterns(prev_stress, curr_stress)`: purely relative patterns (Gtrend, Etrend, Strend, Ptrend, dominantdim) without hard thresholds. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

High-level entrypoint: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- `analyzetext(text, opts)` returns:
  - `features`
  - `stress` (sclaimed)
  - `risk` (composite risk)
  - `effectiverisk` (if resilience vector provided)
  - `discourse` (d, Dneg, Dpos)
  - `discourselabel`
  - `patterns`

The analyzer is deliberately threshold-free; thresholds are externalized to evaluation and playbook logic. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

### 3.2 Debias / distortion analyzer

**Module:** GESP Debias Analyzer  
**File:** `src/gespdebiasanalyzer.lua` [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Purpose: compute distortion vector D, dimension-specific dD, and doom/agency counts, on top of an existing hex GESP model. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Dependencies and integration: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- `models/collapseriskmodel.lua` (“HexModel”): provides `analyzetext(text, opts)` returning sclaimed and hextag 0xGESP. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- External stress estimator: `Debias.estimatestress(context)` returning sestimated (G,E,S,P); callers can override with indicator-based estimators. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Key components: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Lexicons: doom/agency lists and dimension hints for assigning tokens to G,E,S,P. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `countdoomagency(text)`:  
  - tokenizes text;  
  - counts doom/agency totals;  
  - uses dimension hints to attribute counts to dimensions;  
  - returns total and `perdim` = {G={doom,agency}, …}. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `computedD(doomagencycounts)`:  
  - global d = Ndoom / (Ndoom + Nagency);  
  - per-dimension dD similarly;  
  - returns overall and per-dimension. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `labeldD(d, bands)`: label overall discourse orientation. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `computedeltastress(sclaimed, sestimated)`: D = sclaimed − sestimated per dimension. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `summarizedelta(D)`:  
  - per-dimension |D_D|  
  - overall L2 norm. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

High-level entrypoint: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- `Debias.analyzetext(text, context, opts)` returns:
  - `stressclaimed` (from HexModel)  
  - `stressestimated` (from estimator)  
  - `delta` (distortion vector)  
  - `deltasummary` (magnitudes, L2)  
  - `hextag`  
  - `dDoverall`, `dDperdim`, `dDlabel`  
  - `doomagencycounts`  
  - `features` (from HexModel)  

- `Debias.analyzebatch(records, opts)`: batch adapter from corpus rows. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

### 3.3 Risk model integration

**Module:** Collapse risk model  
**File:** `models/collapseriskmodel.lua` (spec described in `docsgespframeworknarrativetoaction.md`) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Purpose: canonical mapping from hex nibbles and indicator-normalized scores to composite Ct and, via docs/nonlinearctexamples.md, to nonlinear coupled and ODE-based dynamics. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Interfaces: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- Maps nibble encodings 0xGESP to sD via sD = vD / 15.  
- Computes Ct = ΣD wD sD and can be extended with coupling terms βDD′ sD sD′. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- Feeds recovery ODE modules that use R and Ct to simulate trajectories. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

***

## 4. Evaluation and logging layer

### 4.1 Validation harness

**Module:** GESP Validation Harness  
**File:** `src/gespvalidationharness.lua` [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Purpose: orchestrate evaluation of Lua analyzers against the gold corpus, compute cost-sensitive metrics, and log rich outputs. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Inputs: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Gold corpus file (`data/corpus_gold.*`) implementing full schema.  
- Analyzer modules:  
  - `src/gespdiscourseanalyzer.lua`  
  - `src/gespdebiasanalyzer.lua`  
  - `models/collapseriskmodel.lua`  

Adapter: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Transforms a corpus record into analyzer inputs (text, context, optional indicators).  
- Ensures analyzer returns sclaimed, dD, doom/agency counts, and patterns compatible with corpus fields. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Outputs per run: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- `output/gold_features_labels.csv`: per-snippet features with gold and predicted values.  
- `output/validation_report.json`:  
  - per-dimension stress MAE, high-stress detection F1;  
  - distortion MAE;  
  - d/dD MAE and doom/agency classification metrics;  
  - claim-type macro/micro F1;  
  - cost-weighted error decompositions;  
  - safety-critical error rates (e.g., S/P false negatives, mislabelled doom-saturated threads). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Invariants: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Analyzer treated as pure function; harness never relies on side effects.  
- Metrics computed per dimension and per doom/agency orientation first; claim-type metrics computed second. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Cost-sensitive evaluation: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Defines a cost matrix with higher weights for:  
  - false negatives on high S or P stress;  
  - mislabeling doom-saturated discourse as balanced or agency-leaning.  
- Reports mean cost per snippet and cost breakdown by dimension and claim type. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

### 4.2 Logging for future ML

The validation harness and analyzers log stable feature vectors for each snippet: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Raw lexical counts (Graw, Eraw, Sraw, Praw, Dnegraw, Dposraw).  
- Normalized stress estimates (sclaimed).  
- d, dD, doom/agency labels.  
- Hex tags and patterns (dominantdim, Gtrend, etc.). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

These logs support future ML/NLP models without refactoring the rule-based stack. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 5. Debunking pipeline and playbook layer

### 5.1 Debunking pipeline

**Module:** Debunking pipeline  
**Spec:** `docs/debunking-pipeline.md` (described across Systematic Debunking docs) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Core objects: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- sD, Ct, R, D, dD, hextag, claimtype, analogytags, casefamily, reframedassessment, interventionlevers, promptsuggestions. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Four-step pipeline: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

1. **Clarify:**  
   - Restate claim concisely.  
   - Assign claimtype and analogytags.  
   - Identify primary dimensions and timeline. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

2. **Measure:**  
   - Use analyzers to obtain sclaimed and dD.  
   - Use context indicators to estimate sestimated.  
   - Compute D. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

3. **Contextualize:**  
   - Compare narrative trajectory to Ct and case-family archetypes (rapid shock, slow hollowing, climate cascade, etc.).  
   - Note resilience and scope (local/national/global). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

4. **Reframe:**  
   - Construct conditional risk statements.  
   - Explicitly describe distortions in D.  
   - Suggest dimension-tagged interventions and prompts that shift dD toward agency. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Implementation hooks: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Operates over the shared schema; can be implemented as a set of functions that consume analyzer outputs and corpus metadata.  
- Produces reframed assessments and lever lists that populate corpus fields and playbook examples. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

### 5.2 Debunking playbook

**Module:** Debunking Playbook v2  
**File:** `docs/debunking-playbook-v2.md` [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Purpose: turn analytic outputs into audience-specific, worked examples and scripts. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Structure: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Organized by claimtype × casefamily × false-analogy pattern.  
- Each entry references corpus snippet IDs, not full copyrighted text.  
- For each pattern: description, typical GESP focus and D signature, example snippets, reframing script, and intervention levers. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Inputs from upstream modules: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- Analyzer outputs and D/dD from Lua modules.  
- Case-family assignments from risk models.  
- Recorded reframed assessments and interventionlevers from debunking pipeline.  

Outputs to downstream consumers: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Narrative templates and explanation patterns used in UIs and prompt libraries.  
- Pedagogical examples for educators and moderators.

***

## 6. Prompts, audiences, and front-end integration

### 6.1 Prompt libraries

**Module:** Prompt libraries  
**Example file:** `prompts/collapse_conversations.json`, `prompts/cyber_conflict_prompts.json` [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Purpose: store reusable, dimension-tagged, audience-specific prompts designed to move conversations from doom to agency. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Each prompt record includes: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- `id`  
- `text`  
- `dimensions`: target dimensions {G,E,S,P}.  
- `audiences`: community organizers, educators, moderators. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `intended_effect_on_dD`: e.g., lower doom in P, raise agency in G.  
- `associated_claimtypes` and `analogytags` (optional).  
- `references`: corpus IDs or playbook sections for worked examples. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Integration: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- Debunking pipeline suggests prompts based on D, dD, claimtype, and analogy tags.  
- Online moderation tools can automatically inject prompts when dD crosses empirical bands.  
- Classroom tools can load prompts aligned with particular fictional works or case studies.

### 6.2 Audience workflows

The architecture supports three primary user workflows: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- **Community organizers:** use pipeline outputs to map local fears to GESP patterns and case families, then select prompts and projects that lower Ct and reduce dS/dP. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- **Educators:** use corpus and analyzers to annotate fiction and news, compare trajectories with historical cases, and design assignments that reframe narratives. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- **Online moderators:** monitor dD over threads, detect doom-saturated conversations, and inject prompts and notes drawn from the playbook. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 7. Risk model and nonlinear dynamics layer

### 7.1 Nonlinear Ct and case-family dynamics

**Specs:**  

- `docs/gespframework-narrativetoaction.md` (core model) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- `docs/nonlinearctexamples.md` (worked nonlinear examples) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- `docs/gesp_case_families.md` (archetypes) [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Purpose: integrate text-derived stress sequences with dynamic models of Ct and R, enabling tipping-point and recovery analyses. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Inputs: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- Time series of hex tags or sD(t) from corpus/analyzers.  
- Resilience parameters R or rD estimated from case data.  

Computation: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Linear composite Ct and coupled Ct with βDD′ terms.  
- Recovery ODEs with or without hysteresis.  
- Early-warning indicators (AR-1, variance, cross-correlation). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Outputs: [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

- Modeled trajectories for archetypes and real cases.  
- Case-family assignments and trajectory notes used by the debunking pipeline and playbook. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 8. Module and interface summary

Below is a concise module-to-interface map.

| Layer | Module / File | Key Inputs | Key Outputs | Contracts / Notes |
| --- | --- | --- | --- | --- |
| Corpus | GESP discourse corpus (`data/gesp_discourse_corpus.*`) | Raw texts, metadata | Claim records with sclaimed, sestimated, D, dD, hextag, claimtype, analogytags, casefamily | Schema defined in `docs/corpus-spec-v2.md`; double-annotated gold slice. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Corpus | Gold subset | Corpus subset | Agreement metrics, guideline patches | Drives annotation quality and ground truth. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Lua | `src/gespdiscourseanalyzer.lua` | text, optional context | features, sclaimed, risk, d, patterns | Threshold-free; normalization delegated to canonical GESP mapping. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md) |
| Lua | `src/gespdebiasanalyzer.lua` | text, context, sestimated fn | sclaimed, sestimated, D, dDoverall, dDperdim, doom/agency counts, hextag | Wraps HexModel; returns structured debias outputs. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Risk | `models/collapseriskmodel.lua` | sD or hex | Ct (linear/nonlinear), hextag mapping | Canonical composite; extended in nonlinear docs. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md) |
| Eval | `src/gespvalidationharness.lua` | gold corpus, analyzers | metrics, cost-weighted error, logs | Reports per-dimension and per-d orientation; logs features. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Debunk | Debunking pipeline docs | claim record w/ analyzer outputs | reframedassessment, interventionlevers, promptsuggestions | Implements Clarify–Measure–Contextualize–Reframe. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Playbook | `docs/debunking-playbook-v2.md` | corpus IDs, D, dD, casefamily | audience-ready worked examples, scripts | Structured by claimtype × analogy × archetype. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Prompts | `prompts/*.json` | D, dD, claimtype, audience | prompt candidates | Dimension- and audience-tagged; integrated via pipeline. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
| Dynamics | `docs/nonlinearctexamples.md`, case-family docs | sD(t), R, βDD′ | Ct(t), early-warning metrics, archetype fits | Used for trajectory notes and educational visualizations. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md) |
