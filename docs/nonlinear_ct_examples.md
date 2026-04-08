# Nonlinear \(C(t)\) Examples: Tipping, Hysteresis, and Coupling

This document provides worked examples of nonlinear composite stress dynamics for the GESP framework. It illustrates how cross-dimensional coupling and bistable recovery can generate tipping points, hysteresis, and cascades in both real and fictional collapse scenarios.

The goal is to give LiteratureHero concrete patterns and parameterizations that can be used in simulations, classification, and debunking tools.

***

## 0. Core Nonlinear Forms

We assume four dimension scores \(s_D(t) \in [0, 1]\) for \(D \in \{G, E, S, P\}\) and a composite stress \(C(t) \in [0, 1]\).

### 0.1 Coupled Composite Stress

Instead of a purely linear composite,

\[
C_{\text{lin}}(t) = \sum_D w_D \, s_D(t),
\]

we introduce pairwise coupling:

\[
C(t) = \sum_D w_D \, s_D(t) + \sum_{D \neq D'} \gamma_{DD'} \, s_D(t) \, s_{D'}(t),
\]

where:

- \(w_D \ge 0\), \(\sum_D w_D = 1\)
- \(\gamma_{DD'}\) are coupling coefficients (possibly asymmetric)
- Positive \(\gamma_{DD'}\) captures amplification (stress in one dimension increases the impact of stress in another)
- Negative \(\gamma_{DD'}\) could represent buffering (rare, but allowed)

### 0.2 Bistable Recovery with Hysteresis

We model recovery as a nonlinear ODE for \(C(t)\):

\[
\frac{dC}{dt} = -k R (C - C_{\text{base}}) + \alpha \, C (1 - C)(C - C_{\text{crit}}),
\]

where:

- \(k > 0\): linear restoring rate
- \(R \in [0, 1]\): resilience parameter (higher means stronger pull toward baseline)
- \(C_{\text{base}}\): baseline stress in ordinary times
- \(\alpha\): nonlinearity strength
- \(C_{\text{crit}}\): critical threshold between “low-stress” and “high-stress” attractors

For appropriate parameter choices, this equation yields:

- Two stable equilibria: one near \(C_{\text{base}}\), one near a high-stress \(C_{\text{collapsed}}\)
- One unstable equilibrium near \(C = C_{\text{crit}}\) acting as a tipping point
- Hysteresis: the \(C\) at which collapse occurs differs from the \(C\) at which recovery becomes self-sustaining

***

## 1. Example A: Economic Crash with Fast Recovery (Rapid Shock, High \(R\))

### 1.1 Setup

We model a short, severe economic crisis that raises \(s_E\) sharply, with moderate increases in \(s_S\) and \(s_P\), and high resilience.

Parameters:

- Weights: \(w_G = 0.2\), \(w_E = 0.3\), \(w_S = 0.25\), \(w_P = 0.25\)
- Non-zero couplings:
  - \(\gamma_{EP} = 0.3\) (economic stress amplifies political stress)
  - \(\gamma_{ES} = 0.2\) (economic stress amplifies social stress)
- Others \(\gamma_{DD'} = 0\)

Stress trajectory (simplified):

- Pre-crash baseline: \(s_G = 0.2, s_E = 0.2, s_S = 0.2, s_P = 0.2\)
- Crash peak: \(s_G = 0.3, s_E = 0.9, s_S = 0.6, s_P = 0.5\)
- Recovery: all scores trend back to ~0.3

Resilience and dynamics:

- \(R = 0.9\), \(k = 1.0\), \(C_{\text{base}} = 0.25\), \(\alpha = 0.2\), \(C_{\text{crit}} = 0.7\)

### 1.2 Composite at Peak

Baseline:

\[
C_{\text{lin,base}} = 0.2 \cdot 0.2 + 0.3 \cdot 0.2 + 0.25 \cdot 0.2 + 0.25 \cdot 0.2 = 0.2.
\]

Peak:

\[
C_{\text{lin,peak}} = 0.2 \cdot 0.3 + 0.3 \cdot 0.9 + 0.25 \cdot 0.6 + 0.25 \cdot 0.5 = 0.06 + 0.27 + 0.15 + 0.125 = 0.605.
\]

Coupling terms at peak:

\[
C_{\text{coup,peak}} = \gamma_{EP} s_E s_P + \gamma_{ES} s_E s_S = 0.3 \cdot 0.9 \cdot 0.5 + 0.2 \cdot 0.9 \cdot 0.6.
\]

Compute:

- \(0.3 \cdot 0.9 \cdot 0.5 = 0.135\)
- \(0.2 \cdot 0.9 \cdot 0.6 = 0.108\)

So:

\[
C_{\text{coup,peak}} = 0.243.
\]

Total:

\[
C_{\text{peak}} = 0.605 + 0.243 = 0.848.
\]

A linear model would report ~0.61, while nonlinear coupling reveals effective stress near 0.85.

### 1.3 Recovery Behavior

At peak \(C = 0.848\):

- Linear term: \(-k R (C - C_{\text{base}}) = -1.0 \cdot 0.9 (0.848 - 0.25) = -0.9 \cdot 0.598 = -0.5382.\)
- Nonlinear term: \(\alpha C (1 - C) (C - C_{\text{crit}})\).

Compute:

- \(1 - C = 0.152\)
- \(C - C_{\text{crit}} = 0.848 - 0.7 = 0.148\)

Then:

- Nonlinear term ≈ \(0.2 \cdot 0.848 \cdot 0.152 \cdot 0.148\)

Approximate the product:

- \(0.848 \cdot 0.152 \approx 0.1290\)
- \(0.1290 \cdot 0.148 \approx 0.0191\)
- Multiply by 0.2 → ≈ 0.0038

So:

\[
\frac{dC}{dt} \approx -0.5382 + 0.0038 \approx -0.5344.
\]

Strongly negative derivative: stress rapidly declines toward \(C_{\text{base}}\).

This example shows:

- Even with high peak stress from coupling, large R pulls the system back.
- Collapse threshold at \(C_{\text{crit}} = 0.7\) is exceeded briefly, but high R keeps the high-stress equilibrium from becoming dominant.

### 1.4 Hex Trajectory and Fiction

- Baseline: 0x3333 (all nibbles ≈ 5).
- Peak: \(s_G \approx 0.3 \rightarrow\) nibble 5, \(s_E \approx 0.9 \rightarrow\) nibble 14, \(s_S \approx 0.6 \rightarrow\) nibble 9, \(s_P \approx 0.5 \rightarrow\) nibble 8 → 0x5E98.
- Recovery: trending back toward 0x4444 then 0x3333.

Fiction that treats this as irreversible collapse is structurally exaggerated. The nonlinear model clarifies that high \(C\) plus high \(R\) looks like a sharp but transient crisis, not a new permanent attractor.

***

## 2. Example B: Climate–Conflict Cascade with Tipping

### 2.1 Setup

Here we model a climate-driven case where G stress gradually rises and triggers coupled increases in E, S, and P, eventually crossing a tipping point into a long-lasting high-stress regime.

Parameters:

- Weights: \(w_G = 0.25\), \(w_E = 0.25\), \(w_S = 0.25\), \(w_P = 0.25\)
- Couplings:
  - \(\gamma_{GE} = 0.4\) (environmental degradation damages economy)
  - \(\gamma_{GS} = 0.3\) (environmental stress increases social conflict)
  - \(\gamma_{GP} = 0.2\) (environmental stress destabilizes politics)
  - \(\gamma_{EP} = 0.3\) (economic hardship fuels political instability)

Slowly changing base:

- Over decades, \(s_G\) increases from 0.2 to 0.8
- Other scores respond via couplings and internal dynamics

Recovery dynamics:

- \(R = 0.4\), \(k = 0.8\), \(C_{\text{base}} = 0.3\), \(\alpha = 0.6\), \(C_{\text{crit}} = 0.6\)

### 2.2 Pre-Tipping State

Take a point where:

- \(s_G = 0.5\)
- \(s_E = 0.4\)
- \(s_S = 0.4\)
- \(s_P = 0.4\)

Linear:

\[
C_{\text{lin}} = 0.25(0.5 + 0.4 + 0.4 + 0.4) = 0.25 \cdot 1.7 = 0.425.
\]

Coupling terms:

\[
C_{\text{coup}} = \gamma_{GE} s_G s_E + \gamma_{GS} s_G s_S + \gamma_{GP} s_G s_P + \gamma_{EP} s_E s_P.
\]

Compute each:

- \(0.4 \cdot 0.5 \cdot 0.4 = 0.08\)
- \(0.3 \cdot 0.5 \cdot 0.4 = 0.06\)
- \(0.2 \cdot 0.5 \cdot 0.4 = 0.04\)
- \(0.3 \cdot 0.4 \cdot 0.4 = 0.048\)

Sum:

- \(C_{\text{coup}} = 0.08 + 0.06 + 0.04 + 0.048 = 0.228.\)

Total:

\[
C = 0.425 + 0.228 = 0.653.
\]

Although individual scores look moderate, coupling pushes \(C\) above 0.65, already beyond \(C_{\text{crit}} = 0.6\).

### 2.3 Dynamics Around the Tipping Point

At \(C = 0.653\):

- Linear term: \(-k R (C - C_{\text{base}}) = -0.8 \cdot 0.4 (0.653 - 0.3)\)

Compute:

- \(0.653 - 0.3 = 0.353\)
- \(0.8 \cdot 0.4 \cdot 0.353 \approx 0.1130\)

So linear term ≈ \(-0.113\).

Nonlinear term:

\[
\alpha C (1 - C) (C - C_{\text{crit}}).
\]

Compute:

- \(1 - C = 0.347\)
- \(C - C_{\text{crit}} = 0.653 - 0.6 = 0.053\)

Product:

- \(C (1 - C) (C - C_{\text{crit}}) \approx 0.653 \cdot 0.347 \cdot 0.053\)
- \(0.653 \cdot 0.347 \approx 0.2265\)
- \(0.2265 \cdot 0.053 \approx 0.0120\)
- Multiply by \(\alpha = 0.6\): ≈ 0.0072

So:

\[
\frac{dC}{dt} \approx -0.113 + 0.0072 = -0.1058.
\]

Still negative, but weakly so. The system is near a “shoulder”: a modest additional push in G or couplings can flip \(\frac{dC}{dt}\) positive.

### 2.4 Post-Tipping High-Stress Attractor

If stress rises slightly so that:

- \(s_G = 0.6\), \(s_E = 0.5\), \(s_S = 0.5\), \(s_P = 0.5\)

Linear:

\[
C_{\text{lin}} = 0.25(0.6 + 0.5 + 0.5 + 0.5) = 0.25 \cdot 2.1 = 0.525.
\]

Couplings at higher values will be larger; suppose they push \(C\) to about 0.75.

At \(C = 0.75\):

- Linear term: \(-0.8 \cdot 0.4 (0.75 - 0.3) = -0.32 \cdot 0.45 = -0.144.\)
- Nonlinear term:

  - \(1 - C = 0.25\)
  - \(C - C_{\text{crit}} = 0.75 - 0.6 = 0.15\)
  - Product: \(0.75 \cdot 0.25 \cdot 0.15 = 0.028125\)
  - Multiply by \(\alpha = 0.6\): ≈ 0.016875

Then:

\[
\frac{dC}{dt} \approx -0.144 + 0.0169 \approx -0.1271.
\]

If couplings and direct driving keep G/E/S/P elevated, the system may settle near a high-stress equilibrium around 0.7–0.8, requiring big changes in R or base stress to exit.

### 2.5 Hex Illustration and Fiction

Selected hex snapshots:

- Early: \(s_D \approx 0.3\) → 0x5555.
- Pre-tipping: \(s_G = 0.5\) and others 0.4 → nibbles ~8,6,6,6 → 0x8666.
- Post-tipping high stress: \(s_G \approx 0.8\), others ≈ 0.7 → 0xCBBA or similar.

In fiction, this case family aligns with stories where climate tension slowly builds until conflict and state failure erupt, often represented as sudden outbreaks of war. The nonlinear model shows that the “suddenness” is a function of dynamics around \(C_{\text{crit}}\) rather than a magic threshold in any single dimension.

***

## 3. Example C: Hysteresis between Collapse and Recovery

### 3.1 Conceptual Setup

Hysteresis means that:

- Collapse may occur when \(C\) crosses a lower threshold \(C_{\text{down}}\)
- Recovery may require reducing \(C\) below a higher threshold \(C_{\text{up}} < C_{\text{down}}\) or raising R above a critical value

We encode this via parameter changes in the ODE and context-dependent R.

### 3.2 Two-Threshold Approximation

Instead of a single \(C_{\text{crit}}\), define:

- Collapse threshold \(C_{\text{collapse}}\): if \(C > C_{\text{collapse}}\) and R is low, system tends toward high-stress equilibrium.
- Recovery threshold \(C_{\text{recover}} < C_{\text{collapse}}\): if \(C < C_{\text{recover}}\) and R is sufficiently high, system tends toward low-stress equilibrium.

While the cubic term implicitly models this, for clarity we can define piecewise behavior:

1. If \(C < C_{\text{recover}}\):  
   - Use higher R: \(R = R_{\text{high}}\)
   - \(dC/dt\) dominated by fast recovery term

2. If \(C > C_{\text{collapse}}\):  
   - Use lower R: \(R = R_{\text{low}}\)
   - Nonlinear term reinforces high-stress basin

3. Between thresholds:  
   - Mixed behavior; coupled with noise and external shocks, system can drift either way.

### 3.3 Numerical Example

Set:

- \(C_{\text{collapse}} = 0.8\)
- \(C_{\text{recover}} = 0.4\)
- \(R_{\text{high}} = 0.8\)
- \(R_{\text{low}} = 0.2\)
- \(k = 1.0\), \(\alpha = 0.4\), \(C_{\text{base}} = 0.3\)

Scenario A: Pre-collapse regime

- System experiences shocks that gradually raise \(C\) from 0.3 to 0.75.
- At \(C = 0.75\), if R is still moderate (say 0.5), it might hover near the tipping point.
- A final shock raises \(C\) to 0.82, beyond \(C_{\text{collapse}}\), and R drops (e.g., institutions weakened) to 0.2.

At \(C = 0.82\), \(R = 0.2\):

- Linear term: \(-1.0 \cdot 0.2 (0.82 - 0.3) = -0.2 \cdot 0.52 = -0.104.\)
- Nonlinear term: positive and larger at this C; suppose it contributes +0.12.

Then:

\[
\frac{dC}{dt} \approx -0.104 + 0.12 = +0.016.
\]

This small positive derivative pushes C further up toward the high-stress equilibrium.

Scenario B: Attempted recovery

Later, reforms or external aid reduce stress somewhat:

- \(C\) is brought down to 0.6, but R remains low at 0.2.

At \(C = 0.6 > C_{\text{recover}}\), with low R, the system is still in the “middle band.”

- Linear term: \(-0.2 (0.6 - 0.3) = -0.06.\)
- Nonlinear term near \(C_{\text{crit}}\) may be close to zero but with coupling, net \(dC/dt\) can remain near 0 or slightly positive.

Thus, modest improvements are insufficient; C can stagnate or drift back up without deeper institutional changes increasing R.

Only when a combination of stress reduction and R-boosting reforms bring:

- \(C < C_{\text{recover}} = 0.4\) and
- \(R\) raised to \(R_{\text{high}} = 0.8\),

does the system reliably flow toward low-stress equilibrium.

### 3.4 Hysteresis and Fiction

Fiction often depicts:

- Collapse as a single catastrophic event
- Recovery as simply “time passes” or “hero solves problem”

The hysteresis model clarifies that:

- Collapse is easier when R has eroded; small shocks can push C past \(C_{\text{collapse}}\).
- Recovery is harder: it requires both lowering C and raising R, often through institution-building, reconciliation, infrastructure rebuilding, and cultural shifts.

Nonlinear examples let LiteratureHero flag stories that underplay how hard recovery is relative to collapse from similar stress levels.

***

## 4. Example D: Comparing Linear vs Nonlinear for the Same Narrative

### 4.1 Hypothetical Fictional World

Consider a fictional setting with:

- Repeated climate shocks
- Rising inequality
- Polarization and emergent authoritarian politics

At a given narrative midpoint, suppose:

- \(s_G = 0.7\)
- \(s_E = 0.6\)
- \(s_S = 0.7\)
- \(s_P = 0.6\)

Weights:

- \(w_D = 0.25\) each

Couplings:

- \(\gamma_{GE} = 0.3\)
- \(\gamma_{GS} = 0.3\)
- \(\gamma_{EP} = 0.2\)
- \(\gamma_{SP} = 0.2\)

### 4.2 Linear Score

\[
C_{\text{lin}} = 0.25(0.7 + 0.6 + 0.7 + 0.6) = 0.25 \cdot 2.6 = 0.65.
\]

Linear interpretation: system is in serious trouble but not necessarily doomed.

### 4.3 Nonlinear Score

Couplings:

- \(C_{\text{coup}} = 0.3(0.7 \cdot 0.6) + 0.3(0.7 \cdot 0.7) + 0.2(0.6 \cdot 0.6) + 0.2(0.7 \cdot 0.6)\)

Compute:

- \(0.7 \cdot 0.6 = 0.42\)
- \(0.7 \cdot 0.7 = 0.49\)
- \(0.6 \cdot 0.6 = 0.36\)

Then:

- \(0.3 \cdot 0.42 = 0.126\)
- \(0.3 \cdot 0.49 = 0.147\)
- \(0.2 \cdot 0.36 = 0.072\)
- \(0.2 \cdot 0.42 = 0.084\)

Sum:

- \(C_{\text{coup}} = 0.126 + 0.147 + 0.072 + 0.084 = 0.429.\)

Total:

\[
C = 0.65 + 0.429 = 1.079,
\]

which saturates at 1.0 in practice.

Thus:

- Linear model: \(C \approx 0.65\)
- Nonlinear model: \(C\) effectively maxed out

### 4.4 Interpretation

In this narrative world:

- Because multiple high stresses overlap with strong couplings, the system is in a genuine collapse basin, not just “high stress.”
- LiteratureHero could recognize that the combination of climate shocks, inequality, polarization, and authoritarianism is more dangerous than any single dimension’s score suggests.

For debunking:

- If a real-world scenario has similar \(s_D\) values but weaker coupling coefficients (because institutions or norms buffer interactions), then the nonlinear model reveals why the same raw stress vector yields lower effective risk.

***

## 5. Implementation Notes for LiteratureHero

To use these examples:

1. **Simulation module:**  
   - Implement a small ODE integrator (e.g., Euler or Runge–Kutta) over the nonlinear \(dC/dt\) form.
   - Let users adjust parameters \(R, k, \alpha, C_{\text{base}}, C_{\text{crit}}\) and \(\gamma_{DD'}\) to explore scenarios.

2. **Narrative mapping:**  
   - From a sequence of hex tags or \(s_D(t)\) extracted from texts, compute:
     - Linear \(C_{\text{lin}}(t)\)
     - Coupled \(C(t)\)
   - Visualize differences and detect when narratives suggest strong coupling dynamics.

3. **Case-family alignment:**  
   - Link each nonlinearity pattern to case families from `gesp_case_families.md`.
   - For example, high R plus sharp spikes → Family 1; strong G→E→S→P couplings with low R → Family 3.

4. **Debunking logic:**  
   - If a collapse claim assumes instant, global failure from modest, isolated stress, compare:
     - Claimed \(s_D\) and couplings
     - Plausible real-world couplings and R
   - Use the nonlinear model to show whether a “rapid total collapse” trajectory is dynamically plausible.
