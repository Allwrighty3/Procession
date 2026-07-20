# Iteration 003: Support-to-Action Translation and Measurement Adequacy

## Identity

- **Iteration:** 003
- **Council:** Procession Experimental Council
- **Inherited state:** `docs/agent_council/council_state.md`
- **Phase:** specified
- **Authority level:** Level 1 specification only; Level 2 implementation requires explicit authorization
- **Previous result:** Iteration 002 existing contradiction efficacy and competitive displacement

## Evidence loaded

The council reviewed:

- the retained Iteration 002 artifact over paired seeds `1..100`;
- unchanged behavioral correction between C0 and doubled disturbance despite increased median support removal;
- measurable support displacement from competition without improved correction;
- stable expression and restoration safeguards;
- zero median post-reversal intake in all four variants;
- the invalid Iteration 002 failure-classifier expression that compared support amount with a dimensionless recovery ratio;
- `CognitiveField.PermeableFlow`, where absolute transition resistance controls surviving activation and relative resistance controls division among exits;
- the current action sampler, which selects from exit activation rather than directly from residue.

The unresolved question is therefore not whether support changes occur. It is whether those changes reach the action-selection boundary strongly enough to alter action probability, and whether the existing reversal scenario provides a meaningful behavioral utility signal.

## Standing role views

### Learner Advocate

- Internal support changes may be real but compressed by resistance or permeability into nearly identical exit activation.
- A support change should not be called behaviorally irrelevant until the complete translation chain is measured.
- Required chain: transition residue, transition resistance, exit activation, normalized exit share, and deterministic sampled action.

### Teacher and Environment Advocate

- The original reversal world may be too unforgiving or too sparse to reveal useful partial adaptation.
- Zero median intake means cumulative intake is not functioning as a useful safeguard.
- A diagnostic scenario may be added only if it preserves the same learner-visible information and differs solely in world-side evaluability.

### Emergence Guardian

- No correct-action label, reversal flag, reward value, semantic utility, or observer measurement may enter learner state.
- Frozen-state probes must be read-only.
- The diagnostic scenario may expose no new information to the entity and may not alter the default learner.

### Measurement Skeptic

- Iteration 003 must prospectively repair units and thresholds.
- Net support must be expressed as support units: residue after recovery minus residue before disturbance, or actual removal minus same-path support redeposited during the fixed window.
- Utility must be measured locally and continuously, not by a median cumulative total that collapses to zero.
- The experiment must distinguish a translation failure from a scenario failure rather than combining them into one verdict.

### OTP and Architecture Guardian

- Elixir remains authoritative for snapshot capture, deterministic probes, scenario execution, and evidence output.
- Snapshot probes must not spawn persistent live entities or alter core `CognitiveField` behavior.
- All new code must remain experiment-local.

### Adjudicator

- **Selected bounded question:** Do support differences produced by the current learner create material differences in resistance, exit activation, and action probability; and, independently, does a non-degenerate access metric reveal useful adaptation that cumulative intake misses?
- **Deferred question:** no new revision mechanism is authorized until translation and measurement adequacy are resolved.

## Diagnostic design

Iteration 003 has two linked but separately adjudicated components.

### Component A — frozen support-to-action transfer probe

Use real field snapshots produced by the existing Iteration 002 variants at three boundaries:

- pre-reversal end;
- post-reversal end;
- restoration end.

For each snapshot and seed:

1. read the transition residue for `:left`, `:right`, and `:remain`;
2. calculate the existing transition resistance for each action without mutation;
3. run the existing `PermeableFlow` configuration with the same activation and exits used by the experiment;
4. record raw exit activation and normalized exit share;
5. sample the existing weighted action under a fixed deterministic probe-seed grid that is identical across compared snapshots;
6. report empirical action-selection frequency across the probe grid.

No learning, disturbance, reinforcement, competition, trace mutation, movement, intake, or world tick occurs during this component.

#### Transfer measurements

For each paired comparison, record:

- support difference by action;
- resistance difference by action;
- exit-activation difference by action;
- normalized exit-share difference by action;
- sampled action-frequency difference by action;
- rank-order agreement among support, exit share, and sampled frequency;
- elasticity: change in normalized exit share divided by change in action support where the support change is non-zero;
- saturation cases where material support differences produce less than `0.01` absolute exit-share change.

### Component B — non-degenerate local access evaluation

Run the unchanged C0 learner and world information boundary under two observer-only evaluations of the same entity-visible history:

- **E0 — existing cumulative intake evaluation:** retain the existing post-reversal intake total for continuity;
- **E1 — local access evaluation:** per tick, record normalized access to the current source as `1 - distance_to_source / world_max`, clipped to `[0, 1]`, plus source-contact rate and improvement-in-access rate.

The entity receives none of these values. Coordinates, source location, distance, and phase remain observer-only.

To determine whether the original scenario itself is degenerate, add one matched diagnostic world schedule:

- **S0 — original reversal:** source switches from one endpoint to the other as currently implemented;
- **S1 — bounded relocation:** source moves from one endpoint to a fixed interior location after reversal, while sensory channels, action availability, learner state, effect delay, coincidence process, and learner-visible experienced deltas remain generated through the same existing functions.

S1 is diagnostic only. It is not a replacement world and cannot support mechanism promotion.

## Factorial structure

Paired deterministic seeds `1..100`:

- **A0:** C0 snapshots, original action-selection configuration, frozen transfer probe;
- **A1:** V1 snapshots, same frozen transfer probe;
- **A2:** V2 snapshots, same frozen transfer probe;
- **A3:** V3 snapshots, same frozen transfer probe.

Scenario evaluation for the unchanged C0 learner:

- **S0:** original endpoint reversal;
- **S1:** bounded interior relocation.

The transfer probe and scenario evaluation produce separate result sections and separate criteria.

## Prospective accounting repair

The following like-for-like measures replace the invalid Iteration 002 classifier expression:

- **gross support removed:** sum of actual residue removed, in support units;
- **same-path support redeposited:** sum of ordinary deposits credited during the fixed five-tick recovery window, in support units;
- **net retained weakening:** gross support removed minus same-path support redeposited, in support units;
- **observed residue change:** residue after recovery minus residue before disturbance, in support units.

The accounting check is valid when the two net measures differ only by explicitly recorded competing deposits, decay, and other transition updates during the same window. Any unexplained residual above `1.0e-9` is an accounting failure.

## Measurements

### Transfer measurements

- support, resistance, exit activation, normalized exit share, and sampled frequency per action;
- Spearman rank agreement among support, exit share, and sampled frequency;
- support-to-exit elasticity;
- count and rate of saturated snapshots;
- proportion of snapshots where the dominant-support action differs from dominant-exit or dominant-sampled action;
- paired differences between C0 and each Iteration 002 treatment.

### Scenario and utility measurements

- cumulative intake;
- mean and median local access;
- source-contact rate;
- improvement-in-access rate;
- obsolete-action rate;
- behavioral correction using the existing definition;
- activity/expression rate;
- post-reversal position distribution;
- restoration behavior for S0 only.

## Registered criteria

### Translation failure supported

Translation failure is supported when all are true:

- at least one treatment has median absolute support change of at least `0.05` on an action transition relative to paired C0;
- median absolute normalized exit-share change for that action is below `0.01`;
- sampled action-frequency change is below `0.02` across the fixed probe grid;
- this pattern occurs in at least `60/100` paired seeds;
- probe replay is byte-identical.

### Translation functioning

Translation is functioning when:

- support rank agrees with exit-share rank in at least `90%` of valid snapshots;
- exit-share rank agrees with sampled-frequency rank in at least `95%` of valid snapshots;
- at least one Iteration 002 treatment produces median absolute exit-share change of at least `0.03` where support changes by at least `0.05`;
- no observer value enters learner state.

Translation functioning does not imply useful learning.

### Scenario/measurement failure supported

Scenario or measurement failure is supported when:

- S0 retains zero median cumulative intake or near-zero source-contact rate;
- S1 raises median local access or source-contact rate by at least `0.15` without changing learner-visible information or action-selection code;
- action expression remains within `10%` between S0 and S1;
- deterministic replay holds.

### Existing intake metric inadequate

The existing intake metric is inadequate when cumulative intake remains zero-median while local access has non-zero interquartile spread and predicts source contact or behavioral correction better than cumulative intake under the registered paired analysis.

### Inconclusive

The result is inconclusive if:

- snapshot capture changes simulation behavior;
- probe output is not deterministic;
- accounting conservation fails;
- S0 and S1 differ in learner-visible inputs beyond consequences generated by the source location;
- fewer than 100 paired seeds remain;
- or transfer and scenario results cannot be separately adjudicated.

## Falsifiers and safeguards

- Frozen probes must not mutate fields or traces.
- Re-running simulation with and without snapshot capture must produce byte-identical histories.
- Probe seeds and snapshot ordering are fixed before execution.
- No correct action, phase, source coordinate, distance, access score, or observer classification enters action selection.
- S1 changes only the world-side source location after reversal.
- Default `AssociationReversalExperiment`, `PermeableFlow`, `CognitiveField`, and action sampling remain unchanged.
- Lower obsolete action through inactivity is not adaptation.
- A useful diagnostic scenario is not an architectural promotion.

## Authorized boundary if Level 2 is granted

- one isolated `SupportActionTranslationExperiment` module;
- read-only snapshot and transfer-probe helpers;
- one deterministic JSONL Mix task;
- focused ExUnit tests;
- one dedicated/manual GitHub Actions evidence workflow;
- iteration-specific registry, result, and council-state updates.

Forbidden changes:

- modifying default learner behavior;
- modifying `PermeableFlow`, `CognitiveField`, or global action sampling;
- adding semantic predictions, rewards, planners, reversal flags, or correct-action labels;
- retuning Iteration 002;
- claiming architectural promotion.

## Required tests

- option and mode validation;
- read-only snapshot capture;
- byte-identical histories with and without capture;
- transfer-chain calculation against direct `CognitiveField.resistance/3` and `PermeableFlow.run/4` calls;
- deterministic probe-grid sampling;
- support-unit accounting and residual validation;
- observer-field isolation;
- S0/S1 learner-visible boundary equivalence;
- exact seed and row coverage;
- byte-identical repeated output;
- full test suite.

## Implementation handoff

Implement Iteration 003 as an isolated diagnostic over existing learner snapshots and a matched observer-only scenario evaluation. Do not introduce a new learner treatment. Measure the complete support-to-action chain, repair support accounting prospectively in like-for-like units, and determine whether the original endpoint reversal and cumulative intake metric are too degenerate to evaluate useful revision. Produce retained deterministic evidence and return the result to the same standing council.

## Execution record

Not yet executed. Iteration 003 is specified but not authorized for implementation.

## Measured result

Unmeasured.

## State handoff

Iteration 003 is active at phase `specified`. The next action is an explicit Level 2 authorization decision for this diagnostic implementation boundary.
