# Debunking Pipeline: From Collapse Claims to Actionable GESP Analysis

This document defines a reusable, GitHub-ready pipeline for analyzing and debunking collapse claims. It links the GESP model, claim typology, distortion vectors, discourse-stress metric \(d_D\), fiction false analogies, and concrete workflows for organizers, educators, and moderators.

The aim is not to “own” people who are worried about collapse, but to turn vague or alarmist claims into structured, evidence-attentive conversations with clear levers for action.

***

## 1. Core Objects and Invariants

The debunking pipeline operates over the following core objects:

- **GESP stress vector** \(s_D \in [0,1]\):  
  For \(D \in \{G, E, S, P\}\), representing Geo/Environmental, Economic, Social, and Political stress.

- **Composite stress** \(C(t)\):  
  A time-varying composite that may include nonlinear coupling and hysteresis, used to distinguish “high stress but stable” from “near tipping” trajectories.

- **Resilience** \(R\):  
  A context-dependent parameter capturing redundancy, institutional robustness, social capital, and recovery capacity.

- **Discourse-stress metric** \(d_D \in [0,1]\):  
  For a given dimension or conversation, defined as  
  \[
  d_D = \frac{N_D^{\text{doom}}}{N_D^{\text{doom}} + N_D^{\text{agency}} + \varepsilon}
  \]  
  where \(N_D^{\text{doom}}\) and \(N_D^{\text{agency}}\) count doom vs agency statements in that dimension.

- **Claim-type label** \(T\):  
  One of the collapse-claim types:
  - Single-Factor Doom  
  - Conspiracy-Driven  
  - Moral Panic  
  - Everything-Is-Broken  
  - Scholarly Risk

- **Dimension distortion vector** \(\Delta_D\):  
  \[
  \Delta_D = s_D^{\text{claimed}} - s_D^{\text{estimated}}
  \]  
  capturing exaggeration or understatement in each dimension.

- **False-analogy type** \(A\):  
  One of the fiction-guided analogies (e.g., Single Shock = Total Collapse, Every Crisis Is Rome, Local Failure = Global Collapse, Violence Equals Collapse, Tech Collapse = Preindustrial Desert, Information Chaos = Immediate Regime Fall).

Key invariants:

- Collapse is multidimensional, processual, and resilience-dependent.  
- Claims must be evaluated against all GESP dimensions and relevant time scales, not just a single spectacular symptom.  
- Doom-heavy discourse without agency undermines problem-solving even when underlying risks are real.

***

## 2. Collapse Claim Typology

This section defines the core claim types and their characteristic patterns. Each type can be combined with one or more false analogies when fiction is invoked.

### 2.1 Single-Factor Doom

**Definition:**  
Claims that attribute imminent or inevitable collapse to a single dominant factor (often climate, debt, or “the elites”), with other dimensions treated as passive or irrelevant.

**Typical structure:**

- One dimension \(D^\*\) is implicitly set to \(s_{D^\*}^{\text{claimed}} \approx 1\).  
- Other dimensions are under-specified or treated as unable to buffer or adapt.  
- Timelines are short (“within a few years,” “any day now”) without explicit mechanism.

**Distortion signature:**

- \(|\Delta_{D^\*}|\) large and positive; \(\Delta_{D \neq D^\*}\) often negative or undefined.  
- Coupling effects are asserted but not supported (e.g., “X will automatically cause total political collapse everywhere”).

### 2.2 Conspiracy-Driven Collapse

**Definition:**  
Claims that collapse is orchestrated by a small, malevolent group, with complex G/E/S dynamics replaced by intentional P- and S-dimension plotting.

**Typical structure:**

- High P and S emphasis (shadow cabal, betrayal, enemies within).  
- G and E dynamics treated as puppets of the conspiracy rather than partially autonomous forces.  
- Evidence is often anecdotal or pattern-based, not systemic.

**Distortion signature:**

- \(\Delta_P\) and \(\Delta_S\) strongly positive; G and E either ignored or flattened.  
- Overstated cross-dimensional control: a few actors are treated as omnipotent.

### 2.3 Moral Panic Collapse

**Definition:**  
Claims that changing norms, culture, or technology imply imminent collapse, centered on disgust, nostalgia, or moral outrage rather than structural indicators.

**Typical structure:**

- S emphasized through narratives of decadence, youth corruption, or cultural rot.  
- P sometimes involved (decay of authority), but G and E rarely quantified.  
- Evidence is mostly rhetorical or anecdotal (stories, memes, isolated incidents).

**Distortion signature:**

- \(\Delta_S\) positive and poorly grounded in measurable S indicators.  
- Neglect of R and of systems that adapt to normative shifts.

### 2.4 Everything-Is-Broken

**Definition:**  
Claims that “everything is failing” and “nothing works anymore,” with all four dimensions described as maximally stressed based on subjective frustration.

**Typical structure:**

- High dramatic language across G/E/S/P without differentiation.  
- Timelines and mechanisms vague; collapse is ambient and constant.  
- Often driven by cumulative annoyance (bureaucracy, tech friction, politics).

**Distortion signature:**

- All \(\Delta_D\) claimed positive, but measurement typically finds high stress in one or two dimensions and moderate or low in others.  
- Composite \(C(t)\) in reality is elevated but far from saturated.

### 2.5 Scholarly Risk

**Definition:**  
Analytically grounded assessments using explicit indicators, uncertainty ranges, and time horizons. Not a “false” claim type, but a reference class.

**Typical structure:**

- Clear distinction between near-term disruptions and long-term systemic risk.  
- Explicit data sources, models, and assumptions.  
- Stress and risk expressed probabilistically or conditionally.

**Distortion signature:**

- \(\Delta_D\) typically small; any exaggeration is flagged as scenario-based rather than prediction.  
- dD often balanced: concern paired with discussion of levers and pathways.

***

## 3. Dimension Distortion Vector \(\Delta_D\)

The distortion vector quantifies how far a claim’s implied stress deviates from the best-available estimate.

For each dimension \(D\):

- **Claimed stress** \(s_D^{\text{claimed}}\):  
  Stress level implied by the rhetoric, treated as a latent variable extracted from text (e.g., via the Lua analyzer plus claim-type heuristics).

- **Estimated stress** \(s_D^{\text{estimated}}\):  
  Stress level from data, expert synthesis, or calibrated models in the relevant context.

- **Distortion** \(\Delta_D = s_D^{\text{claimed}} - s_D^{\text{estimated}}\):  
  Positive values indicate exaggeration; negative values indicate underplaying stress.

### 3.1 Extracting \(s_D^{\text{claimed}}\)

From text:

- Use the lexical G/E/S/P features and normalized scores from the Lua analyzer.  
- Adjust for intensifiers and absolutes (“total,” “irreversible,” “nothing left”) to infer whether the narrator is treating a dimension as near-maxed.  
- Map doom-heavy statements about a specific dimension (e.g., “there’s nothing we can do about rising seas”) to high \(s_D^{\text{claimed}}\) for that D.

### 3.2 Obtaining \(s_D^{\text{estimated}}\)

From context:

- Use calibrated indicator mappings (e.g., FSI components, economic indicators, climate impact metrics, governance scores).  
- Apply context-specific weights and normalization agreed in the repository.  
- When uncertainty is high, represent \(s_D^{\text{estimated}}\) as an interval and propagate that into \(\Delta_D\) bounds.

### 3.3 Using \(\Delta_D\) in debunking

Given a claim:

1. Compute or approximate \(\Delta_G, \Delta_E, \Delta_S, \Delta_P\).  
2. Identify which dimensions are most distorted (largest \(|\Delta_D|\)).  
3. Explain, in plain language, where the claim overstates or understates stress and where it is roughly aligned.  
4. Link distortions to the claim type:
   - Single-Factor Doom: one large \(\Delta_D\), others neglected.  
   - Everything-Is-Broken: all \(\Delta_D > 0\), but data show only one or two truly high.

This creates a transparent bridge between narrative and indicators.

***

## 4. Discourse-Stress dD and Fictional False Analogies

The discourse-stress metric \(d_D\) and the false-analogy catalog complement \(\Delta_D\) by focusing on language balance and narrative tropes, especially when fiction is invoked.

### 4.1 dD and dimension-specific doom vs agency

For each dimension D:

- Count doom-like tokens and phrases (e.g., “too late,” “nothing we can do,” “inevitable,” “doomed”) → \(N_D^{\text{doom}}\).  
- Count agency-like tokens and phrases (e.g., “organize,” “adapt,” “reform,” “build,” “protect”) → \(N_D^{\text{agency}}\).  
- Compute \(d_D\) and optionally aggregate into an overall d-score for the text.

Interpretation:

- \(d_D \approx 1\): discourse dominated by helplessness.  
- \(d_D \approx 0.5\): mixed doom and agency.  
- \(d_D \approx 0\): heavily agency-driven (risk may be underplayed).

The goal is not to drive \(d_D\) to zero, but to avoid sustained \(d_D \to 1\) states that paralyze action.

### 4.2 Fictional false analogies

False analogies are mappings from fictional scenarios to real-world contexts that misrepresent structure, scale, or time.

Examples:

- **Single Shock = Total Collapse:** one blackout or attack is treated as equivalent to permanent global collapse.  
- **Every Crisis Is Rome:** any sign of decadence is equated with imperial fall.  
- **Local Failure = Global Collapse:** a country’s crisis is treated as worldwide civilizational failure.  
- **Violence Equals Collapse:** visible violence is equated with full systemic breakdown.  
- **Tech Collapse = Preindustrial Desert:** digital failure is treated as immediate, permanent reversion to preindustrial living.  
- **Information Chaos = Immediate Regime Fall:** misinformation alone is treated as sufficient to topple robust institutions.

Each analogy has characteristic G/E/S/P fingerprints and typical distortions. Embedding these patterns allows LiteratureHero to:

- Detect when a claim is borrowing imagery or logic from collapse fiction.  
- Explain why the analogy is structurally weak (e.g., missing R, ignoring spatial heterogeneity, mis-timing dynamics).  
- Suggest more accurate case families and trajectories.

***

## 5. Four-Step Debunking Pipeline

The pipeline operationalizes the above components into a repeatable procedure.

### Step 1: Clarify

**Goal:** Identify what is being claimed and in which structure.

Tasks:

- Extract the core claim in one or two sentences:
  - “X will inevitably collapse within Y because of Z.”  
- Assign a claim type \(T\) and any invoked false-analogy types \(A\).  
- Identify the primary dimensions the claim focuses on and the implied timeline (months, years, decades).

Outputs:

- `claim_core`: concise restatement.  
- `claim_type`: one of the five.  
- `analogy_tags`: zero or more false-analogy labels.  
- `focus_dimensions`: subset of {G,E,S,P}.  
- `claimed_timeline`: qualitative or quantitative.

### Step 2: Measure

**Goal:** Quantify both narrative and data-based stress.

Tasks:

- Use the Lua analyzer to obtain:
  - Lexical G/E/S/P scores → approximate \(s_D^{\text{claimed}}\).  
  - Doom/agency counts → \(d_D\).  
- Pull context-specific indicators to estimate \(s_D^{\text{estimated}}\).  
- Compute the distortion vector \(\Delta_D\).

Outputs:

- `s_claimed`: vector of claimed stress.  
- `s_estimated`: vector of estimated stress.  
- `delta`: distortion vector.  
- `dD`: discourse-stress scores by dimension and overall.

### Step 3: Contextualize

**Goal:** Place the claim within GESP dynamics, nonlinear behavior, and historical patterns.

Tasks:

- Examine whether the claim’s implied trajectory is:
  - Linear overstatement (everything just “gets worse”), or  
  - Nonlinear (tipping, cascade, hysteresis) with no supporting mechanism.  
- Compare to relevant case families and historical cases:
  - Rapid shock with high R vs low R.  
  - Slow hollowing vs external conquest vs climate cascade.  
- Check whether spatial structure and resilience are acknowledged:
  - Local vs global.  
  - Presence of buffers and alternative trajectories.

Outputs:

- `trajectory_notes`: narrative vs plausible \(C(t)\) behavior.  
- `case_family`: one or more archetypes that better fit data.  
- `resilience_notes`: where R is ignored, understated, or overstated.  
- `scope_notes`: local/regional/global and how that compares to the claim.

### Step 4: Reframe

**Goal:** Replace deterministic doom with conditional risk and clear levers, while respecting legitimate concerns.

Tasks:

- Construct a conditional risk statement:
  - “If A and B continue, then risk in dimension C increases over horizon H, but actions X, Y, Z can reduce this risk.”  
- Point out distortions explicitly but non-dismissively:
  - “This claim is right that S stress is rising, but it exaggerates G and P stress and treats R as zero.”  
- Suggest dimension-targeted interventions and conversation prompts that lower dD and raise perceived efficacy:
  - G: local adaptation, infrastructure, preparedness.  
  - E: policy reforms, safety nets, diversification.  
  - S: trust-building, bridging projects.  
  - P: institutional guardrails, participation, anti-corruption measures.

Outputs:

- `reframed_assessment`: structured, conditional summary.  
- `intervention_levers`: dimension-tagged actions.  
- `prompt_suggestions`: GESP- and claim-type-matched conversation starters.

***

## 6. Example Workflows by Audience

This section sketches how the pipeline can be used by three primary user groups.

### 6.1 Community organizers

**Use case:** Local group worried about “everything collapsing soon” due to climate, housing, or unrest.

Workflow:

1. **Clarify:**  
   - Capture typical statements in a meeting or online thread.  
   - Classify claim types and analogies (often Everything-Is-Broken + Single-Factor Doom).

2. **Measure:**  
   - Run snippets through the analyzer to get rough \(s_D^{\text{claimed}}\) and dD.  
   - Use local indicators (heatwaves, housing costs, turnout, crime) to estimate \(s_D^{\text{estimated}}\).  
   - Identify where perceptions diverge most (\(\Delta_D\)).

3. **Contextualize:**  
   - Map local stress to case families: perhaps “high G and E, moderate S, still-functional P.”  
   - Check whether the group is treating a “rapid shock with high R” as “irreversible total collapse.”

4. **Reframe:**  
   - Present a one-page summary: “Here’s where things are genuinely stressed; here’s where we still have capacity and options.”  
   - Use dimension-tagged prompts to shift dD toward agency (e.g., “What local steps on G and S do we control?”).  
   - Turn the conversation into a project list (“What can we do this year?”) rather than a doom rehearsal.

### 6.2 Educators

**Use case:** Teaching with collapse fiction (novels, films, games) and comparing to real-world dynamics.

Workflow:

1. **Clarify:**  
   - Pick a fictional work; identify its dominant claim types and false analogies.  
   - Ask students to map scenes to G/E/S/P and to claim types.

2. **Measure:**  
   - Annotate selected passages with \(s_D^{\text{claimed}}\), hex tags, and dD.  
   - Contrast with historical cases where similar stress did and did not lead to collapse.

3. **Contextualize:**  
   - Use nonlinear \(C(t)\) examples to show where fiction compresses time or exaggerates couplings.  
   - Discuss resilience and recovery that fiction may omit.

4. **Reframe:**  
   - Ask students to write alternative scenes where institutions adapt or where different choices change trajectories.  
   - Connect fictional “what if”s to real debates about policy, technology, and community action.

This trains students to see fiction as a tool for thinking, not a forecast.

### 6.3 Online moderators and platform stewards

**Use case:** Threads spiraling into “we’re doomed, nothing matters” discussions that demotivate participants.

Workflow:

1. **Clarify:**  
   - Monitor conversations for high dD (doom-dominant talk) and common claim types.  
   - Automatically tag threads with likely claim types and analogies.

2. **Measure:**  
   - Use lightweight analysis to track dD over time by dimension.  
   - Detect when S or P conversations become doom-saturated.

3. **Contextualize:**  
   - Use a library of typical distortions to generate mod-side notes: “This thread conflates local failure with global collapse; here’s the structural difference.”

4. **Reframe:**  
   - Inject pre-written, audience-appropriate prompts that invite agency:
     - “What concrete actions in our community could reduce the risks you’re naming?”  
     - “Which institutions still work reasonably well, and how could they be strengthened?”  
   - Encourage sharing of constructive examples, not just grievances.

Over time, this can reduce the prevalence of threads stuck at \(d_D \approx 1\).

***

## 7. Implementation Notes and File Interfaces

For integration into LiteratureHero, the pipeline expects a few standard structures.

### 7.1 Claim schema

A minimal JSON-like schema for a claim record:

- `id`: unique identifier.  
- `text`: raw claim text.  
- `context`: metadata (source, date, location, audience).  
- `claim_type`: one of the five, plus confidence.  
- `analogy_tags`: list of false-analogy labels.  
- `s_claimed`: G/E/S/P claimed stress.  
- `s_estimated`: G/E/S/P estimated stress.  
- `delta`: distortion vector.  
- `dD`: doom/agency scores.  
- `case_family`: best-fit archetype(s).  
- `reframed_assessment`: structured text.  
- `intervention_levers`: dimension-tagged actions or policies.  
- `prompt_suggestions`: references into a prompt library.

### 7.2 Lua and corpus interface

- The Lua analyzer should expose an `analyze_text` entrypoint that returns:
  - Features (lexical counts).  
  - Stress estimates (for s_claimed).  
  - dD and qualitative labels.  
  - Relative-pattern hints (which dimensions are emphasized, rising, or neglected).

- The GESP discourse corpus should include:
  - Columns for claim_type, analogy_tags, s_claimed, s_estimated, delta, dD.  
  - Separate subsets for fiction, news, and social media.

***

## 8. G/E/S/P Usefulness Tag and USR

This debunking pipeline document advances LiteratureHero’s goals by:

- **Geo (G):** Structuring how environmental and tech-collapse claims are tied back to indicators and nonlinear dynamics.  
- **Eco (E):** Clarifying how economic stress is distinguished from full systemic collapse and how to quantify overstatement.  
- **Social (S):** Providing an explicit role for discourse balance (dD) and for fiction-driven analogies in shaping perceptions.  
- **Political (P):** Offering tools to differentiate between institutional stress, conspiratorial narratives, and actual regime fragility.

G/E/S/P tag for this module: **0x9DEF**  
USR (Useful-Score Rating): **0xA0** (high leverage for debunking, pedagogy, and tool integration).
