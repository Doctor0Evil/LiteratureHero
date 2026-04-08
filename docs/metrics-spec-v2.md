# Metrics and Label Catalog v2.0

This document enumerates and formalizes the metrics and labels used in the LiteratureHero GESP and debunking pipeline, with domains, intended uses, and cost-weighting guidance. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

## 0. Core objects and notation

We assume the following core quantities. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

- Dimension set: \(D \in \{G,E,S,P\}\) for GeoEnvironmental, Economic, Social, Political.  
- Normalized stress scores: \(s_D \in [0,1]\) for each dimension.  
- Claimed vs estimated stress: \(s_D^{claimed}\), \(s_D^{estimated}\).  
- Distortion vector: \(D_D = s_D^{claimed} - s_D^{estimated}\).  
- Composite stress: \(C_t\) (linear or nonlinear), from GESP scores.  
- Doom/agency counts: \(N_{D,doom}\), \(N_{D,agency}\), and totals \(N_{doom}, N_{agency}\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- Discourse-stress metric: \(d_D \in [0,1]\) and overall \(d \in [0,1]\).  
- Claim-type labels: five collapse-claim families.  
- False-analogy tags: trope-based labels for fiction-to-reality mis-mapping.  
- Hex GESP tags: 0xGESP with per-dimension nibbles.  
- Resilience scores: scalar \(R\) and optionally per-dimension \(r_D\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

Each metric below specifies: name, definition, domain, intended use (safety-critical vs descriptive), and cost-weighting notes where relevant. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

***

## 1. Dimension stress metrics

### 1.1 Dimension stress MAE (regression)

**Name:** Dimension stress MAE per D  
**Symbol:** \(\text{MAE}_{s_D}\)  
**Definition:** For gold-annotated stress \(s_D^{gold}\) and predicted \(\hat{s}_D\), over N snippets:  
\[
\text{MAE}_{s_D} = \frac{1}{N} \sum_{i=1}^N | \hat{s}_{D,i} - s_{D,i}^{gold} |
\]  
**Domain:** Regression on \([0,1]\) per dimension. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
**Intended use:** Safety-critical for S and P, important for G and E. Used to check calibration of the stress backbone that feeds D, Ct, and case-family mapping. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
**Cost weighting:** Optionally weight errors by dimension:  
- Higher weight for \(\text{MAE}_{s_S}\), \(\text{MAE}_{s_P}\) (missing social/political stress is more dangerous).  
- Lower weight for modest G/E errors in contexts where overestimation mainly triggers review. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

### 1.2 High-stress detection metrics (classification)

**Name:** High-stress detection Precision/Recall/F1 per D  
**Definition:** Define a data-driven threshold \(\tau_D\) (e.g., 75th percentile of \(s_D^{gold}\)). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- Ground truth label: \(y_D^{gold} = 1\) if \(s_D^{gold} \ge \tau_D\), else 0.  
- Predicted label: \(\hat{y}_D = 1\) if \(\hat{s}_D \ge \tau_D\), else 0. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

Compute precision, recall, F1 in the usual way per dimension. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Binary classification per dimension.  
**Intended use:** Safety-critical for high-stress detection (especially S, P), used for validation harness reports and cost-sensitive analysis. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
**Cost weighting:**  
- Assign higher cost to false negatives on high S or P.  
- Lower cost to false positives in low-risk dimensions where extra scrutiny is acceptable. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 2. Distortion metrics

### 2.1 Distortion MAE (regression)

**Name:** Distortion MAE per D  
**Symbol:** \(\text{MAE}_{D_D}\)  
**Definition:** Distortion is \(D_D = s_D^{claimed} - s_D^{estimated}\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

For gold-annotated distortion \(D_D^{gold}\) and predicted \(\hat{D}_D\):  
\[
\text{MAE}_{D_D} = \frac{1}{N} \sum_{i=1}^N | \hat{D}_{D,i} - D_{D,i}^{gold} |
\]  
**Domain:** Regression on \([-1,1]\) (or clipped to \([-1,1]\)).  
**Intended use:** High leverage for debunking; not directly safety-critical but central to explanatory quality (where and how claims exaggerate or understate). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
**Cost weighting:**  
- Optionally weight overstatement and understatement differently.  
- In prevention-focused deployments, understating real stress in S/P can be more costly than overstating it.

### 2.2 Distortion magnitude and norms (descriptive)

**Name:** Distortion magnitude per D, distortion L2 norm  
**Definition:**  
- Per-dimension magnitude: \(|D_D|\).  
- Overall distortion norm: \(\|D\|_2 = \sqrt{\sum_D D_D^2}\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)  

**Domain:** Regression/continuous, used for ranking and visualization.  
**Intended use:** Descriptive; used to highlight strongly distorted claims, to drive playbook templates (e.g., strong Single-Factor Doom patterns). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
**Cost weighting:** None intrinsic; can be combined with claim-type and dimension for prioritization.

***

## 3. Doom/agency and discourse-stress metrics

### 3.1 Doom/agency token counts

**Name:** Doom/agency counts (global and per dimension)  
**Symbols:**  
- Global: \(N_{doom}, N_{agency}\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- Per dimension: \(N_{D,doom}, N_{D,agency}\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Definition:**  
- Doom tokens: lexical items like “inevitable”, “too late”, “nothing we can do”, “doomed”, “collapse is certain”, “no way out”.  
- Agency tokens: “organize”, “adapt”, “mitigate”, “reform”, “protect”, “build”, “cooperate”, “mobilize”, etc. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- Dimension hints: assign occurrences to D when doom/agency tokens co-occur with dimension-specific vocabulary (climate/grid for G, jobs/housing for E, community/trust/riot for S, government/election/coup for P). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Raw integer counts per snippet or conversation.  
**Intended use:** Inputs to dD metrics; descriptive features for playbook and validation harness. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
**Cost weighting:** None directly; used upstream of safety-critical dD estimates.

### 3.2 Global discourse-stress d (regression)

**Name:** Global discourse-stress  
**Symbol:** \(d\)  
**Definition:**  
\[
d = \frac{N_{doom}}{N_{doom} + N_{agency}}
\]  
with smoothing if denominator is zero. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Domain:** Regression on \([0,1]\).  
**Interpretation:**  
- \(d \approx 1\): doom-dominated, little agency.  
- \(d \approx 0.5\): mixed.  
- \(d \approx 0\): heavily agency-framed, possibly underplaying risk. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Intended use:** Safety-relevant for discourse health (detection of paralyzing threads); used in interventions (prompt selection) and evaluation (MAE on d). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
**Cost weighting:**  
- High cost for misclassifying doom-saturated discourse as balanced or agency-leaning.  
- Lower cost for slight overestimation of doom (which mostly triggers discussion). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

### 3.3 Per-dimension discourse-stress dD (regression)

**Name:** Dimension-specific discourse-stress  
**Symbol:** \(d_D\)  
**Definition:**  
\[
d_D = \frac{N_{D,doom}}{N_{D,doom} + N_{D,agency}}
\]  
with smoothing for zero-denominator cases. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Regression on \([0,1]\) per dimension.  
**Intended use:** Safety-relevant for conversations about specific dimensions (e.g., S doom spirals); supports dimension-tagged prompts and fine-grained evaluation (MAE per dD). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
**Cost weighting:**  
- Heavier penalties when S or P dD is near 1 but predicted as mixed (missed doom saturation in social/political discourse).  
- Lighter penalties for moderate errors in G/E dD when used mainly for tone analysis.

### 3.4 d / dD qualitative labels (classification)

**Name:** Discourse-stress band labels  
**Labels:** e.g., “agency-leaning”, “mixed”, “doom-leaning”, “doom-saturated”. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Definition:**  
- Empirical bands derived from d or dD distributions (e.g., quantile cutpoints), not hard-coded constants. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Ordinal classification from continuous d/dD.  
**Intended use:** Descriptive and UX-focused; feeds playbook logic (which prompts to inject) and moderator dashboards. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
**Cost weighting:**  
- Mislabeling doom-saturated as mixed is safety-critical.  
- Mislabeling mixed as doom-leaning is low-stakes, mainly UX.

### 3.5 d / dD error metrics

**Name:** MAE on d, MAE on dD  
**Definition:**  
- Global: \(\text{MAE}_d = \frac{1}{N} \sum_i | \hat{d}_i - d_i^{gold} |\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)  
- Per dimension: \(\text{MAE}_{d_D} = \frac{1}{N} \sum_i | \hat{d}_{D,i} - d_{D,i}^{gold} |\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)  

**Domain:** Regression.  
**Intended use:** Primary evaluation metrics for discourse-stress tools; safety-relevant in contexts where d drives interventions. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
**Cost weighting:** Emphasize cases with true d or dD near 1 where underestimation is especially harmful.

***

## 4. Claim-type labels and metrics

### 4.1 Claim-type labels (classification)

**Name:** Collapse claim-type label  
**Label set:**  
- Single-Factor Doom  
- Conspiracy-Driven  
- Moral Panic  
- Everything-Is-Broken  
- Scholarly Risk [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Definition:** Structural templates based on distortion patterns D, distribution of GESP focus, and discourse-stress profile. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Domain:** Multiclass classification; potentially multi-label for mixed cases.  
**Intended use:** Descriptive, pedagogical, and debunking-oriented; not primary safety metric but key for explanation and playbook routing. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Metrics:**  
- Macro-averaged precision/recall/F1 over the five types.  
- Confusion matrices to inspect confusions between, e.g., Moral Panic vs Everything-Is-Broken. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Cost weighting:**  
- Generally uniform; can assign slightly higher cost to misclassifying Scholarly Risk as doom types (penalizing evidence-based cautious claims).  
- But still subordinate to dimension-level and dD metrics.

### 4.2 Claim-type agreement metrics

**Name:** Inter-annotator agreement on claimtype  
**Metrics:** Cohen’s kappa or similar measures. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Agreement classification.  
**Intended use:** Research and corpus quality control; not directly safety-critical but foundational for reliable evaluations. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 5. False-analogy tags and metrics

### 5.1 False-analogy labels

**Name:** False-analogy tags  
**Examples:**  
- Single Shock Total Collapse  
- Every Crisis Is Rome  
- Local Failure Global Collapse  
- Violence Equals Collapse  
- Tech Collapse = Preindustrial Desert  
- Information Chaos ⇒ Immediate Regime Fall [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Domain:** Multi-label classification; each snippet can carry multiple analogy tags.  
**Intended use:** Descriptive, debunking-oriented; anchors fiction-to-reality mismatch analyses and playbook examples. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Metrics:**  
- Multi-label agreement (e.g., Jaccard similarity, Krippendorff’s alpha).  
- Optional multi-label precision/recall/F1 if automated analogy tagging is implemented. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Cost weighting:**  
- No direct safety-critical role; mis-tags mainly affect explanation quality and pedagogy.

***

## 6. Hex GESP tags and derived metrics

### 6.1 Hex GESP tags

**Name:** Hex stress tag  
**Format:** 0xGESP  
- Each nibble \(v_D \in \{0,\dots,15\}\).  
- Mapping: \(s_D = v_D/15\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Domain:** Discrete ordinal coding of stress levels; used for indexing, visualization, and archetype mapping.  
**Intended use:** Descriptive; compact representation of stress; essential for case-family classification and fiction-real comparisons. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Metrics:**  
- Per-dimension nibble MAE (e.g., mean |v_D^{pred} − v_D^{gold}|).  
- Hex trajectory similarity measures (for archetype recognition). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Cost weighting:** None intrinsic; nibble errors translate back to sD and Ct metrics where costs apply.

***

## 7. Resilience and composite risk metrics

### 7.1 Resilience scores

**Name:** Resilience scalar and vector  
**Symbols:**  
- Global: \(R \in [0,1]\).  
- Per dimension: \(r_D \in [0,1]\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Definition:**  
- Conceptual: capacity to absorb shocks and recover without regime change.  
- Optional effective risk function:  
  \[
  C_{eff} = \sum_D w_D\, s_D (1 - r_D)
  \]  
  capturing risk after resilience buffers. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Domain:** Regression; R and rD are latent parameters, estimated from case data and used in models.  
**Intended use:** Safety-relevant for scenario modeling (distinguishing high-stress/high-R vs high-stress/low-R); central for nonlinear Ct examples and archetype dynamics. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Metrics:**  
- Calibration exercises comparing modeled recovery speed to historical trajectories.  
- No direct scalar “accuracy” yet; treated as model parameters.

### 7.2 Composite stress and ODE metrics

**Name:** Composite stress Ct and recovery ODE fit  
**Definitions:**  
- Linear composite: \(C_t = \sum_D w_D s_D(t)\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- Coupled composite: add pairwise terms \(\beta_{DD'} s_D s_{D'}\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)
- Linear recovery: \(\frac{dC}{dt} = -k R (C - C_{base})\). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
- Bistable recovery: add nonlinear term for hysteresis. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Regression; time-series modeling.  
**Intended use:** Descriptive and scenario-level safety (tipping vs recoverable trajectories); used for case-family examples and educational plots. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

**Metrics:**  
- Fit to historical or synthetic trajectories (e.g., squared error over time).  
- Early-warning metrics (autocorrelation, variance) described below.

### 7.3 Early-warning indicators

**Name:** Early-warning metrics on Ct and sD  
**Definitions:** Over sliding windows on time series:  
- AR(1) autocorrelation.  
- Rolling variance.  
- Recovery rate (time back to baseline after shocks).  
- Cross-correlation between dimensions. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Regression/time-series; descriptive with safety implications.  
**Intended use:** Identify systems approaching tipping points; map fiction trajectories to early-warning analogues; design “near-miss” vs “collapse” pedagogy. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Cost weighting:** Not yet cost-weighted in evaluation; more about qualitative phase detection.

***

## 8. Corpus and agreement metrics

### 8.1 Gold-subset agreement metrics

**Name:** Inter-annotator metrics for key fields  
**Fields:** claimtype, analogytags, focusdimensions, sclaimed, sestimated, dD, d, doom/agency label, etc. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Metrics:**  
- Cohen’s kappa for single-label fields (claimtype, doom/agency label).  
- Alpha or Jaccard-based scores for multi-label fields (false analogies, focus dimensions).  
- Mean absolute differences for continuous fields (sclaimed, sestimated, d, dD). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Agreement/quality assessment.  
**Intended use:** Research and corpus governance; not directly safety-critical but necessary for trustworthy metrics downstream. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

***

## 9. Cost-sensitive metrics

### 9.1 Cost-weighted error for stress and dD

**Name:** Cost-weighted loss L  
**Definition (generic form):**  
\[
L = \sum_D (\lambda^{FN}_D \cdot FN_D + \lambda^{FP}_D \cdot FP_D)
\]  
where FN/FP are counts of false negatives/positives for high-stress classifications or doom-saturation labels. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Domain:** Risk-weighted classification loss.  
**Intended use:** Safety-critical optimization; instructs models and calibration routines to prioritize certain errors over others (e.g., missing high S/P stress, mislabeling doom-saturated discourse as balanced). [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/71fad947-9120-4b1d-8ebe-bbe7f914e545/this-research-focuses-on-advan-GQIpnT_IQNO7ZSfyz6fVcg.md)

**Cost weighting hints:**  
- \(\lambda^{FN}_S, \lambda^{FN}_P\) > \(\lambda^{FN}_G, \lambda^{FN}_E\) in conflict/instability monitoring.  
- Additional term for mislabeling high-d or high-dD as low or mixed.  
- Report both unweighted metrics and L per run.

***

## 10. Metric and label registry summary (JSON/Lua structure)

For code consumption, the metrics above can be exposed as a registry object, listing each metric with its properties. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)

A minimal JSON-like schema:

```json
{
  "metrics": [
    {
      "name": "dimension_stress_mae",
      "symbol": "MAE_sD",
      "type": "regression",
      "inputs": ["sD_pred", "sD_gold"],
      "outputs": ["mae_per_D"],
      "safety_critical": true,
      "dimensions": ["G", "E", "S", "P"],
      "cost_weighting": {
        "hint": "upweight_S_P_false_negatives"
      }
    },
    {
      "name": "distortion_mae",
      "symbol": "MAE_DD",
      "type": "regression",
      "inputs": ["D_pred", "D_gold"],
      "outputs": ["mae_per_D"],
      "safety_critical": false,
      "dimensions": ["G", "E", "S", "P"],
      "cost_weighting": {
        "hint": "optional_asymmetric_over_vs_understatement"
      }
    },
    {
      "name": "doom_agency_counts",
      "type": "feature",
      "inputs": ["text"],
      "outputs": [
        "N_doom",
        "N_agency",
        "N_D_doom",
        "N_D_agency"
      ],
      "safety_critical": false
    },
    {
      "name": "discourse_stress_global",
      "symbol": "d",
      "type": "regression",
      "inputs": ["N_doom", "N_agency"],
      "outputs": ["d"],
      "safety_critical": true,
      "cost_weighting": {
        "hint": "penalize_underestimation_near_1"
      }
    },
    {
      "name": "discourse_stress_per_dimension",
      "symbol": "dD",
      "type": "regression",
      "inputs": ["N_D_doom", "N_D_agency"],
      "outputs": ["dG", "dE", "dS", "dP"],
      "safety_critical": true
    },
    {
      "name": "claim_type_label",
      "type": "classification",
      "labels": [
        "Single-Factor Doom",
        "Conspiracy-Driven",
        "Moral Panic",
        "Everything-Is-Broken",
        "Scholarly Risk"
      ],
      "safety_critical": false
    },
    {
      "name": "false_analogy_tags",
      "type": "multilabel",
      "labels": [
        "Single Shock Total Collapse",
        "Every Crisis Is Rome",
        "Local Failure Global Collapse",
        "Violence Equals Collapse",
        "Tech Collapse Preindustrial Desert",
        "Information Chaos Immediate Regime Fall"
      ],
      "safety_critical": false
    },
    {
      "name": "hex_gesp_tag",
      "type": "encoding",
      "inputs": ["vG", "vE", "vS", "vP"],
      "outputs": ["0xGESP", "sG", "sE", "sS", "sP"],
      "safety_critical": false
    },
    {
      "name": "resilience_scalar",
      "symbol": "R",
      "type": "regression",
      "inputs": ["case_features"],
      "outputs": ["R"],
      "safety_critical": descriptive
    },
    {
      "name": "cost_weighted_loss",
      "symbol": "L",
      "type": "risk_weighted_loss",
      "inputs": ["FN_counts", "FP_counts", "lambda_FN", "lambda_FP"],
      "outputs": ["L"],
      "safety_critical": true
    }
  ]
}
```

A Lua-table equivalent can mirror this schema for direct use in the validation harness and analyzers. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/collection_f46a01b0-2ad3-4994-8ca1-21c715ce33fc/269055ec-4808-430d-a940-01aa61f75650/from-narrative-to-action-a-g-e-PRabkzFmSkSm7GMuv7HaDg.md)
