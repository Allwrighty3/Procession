# Iteration 002: Existing Contradiction Efficacy and Competitive Displacement

## Identity

- **Iteration:** 002
- **Council:** Procession Experimental Council
- **Phase:** closed
- **Authority used:** Level 2, limited to the corrected isolated factorial
- **Architectural promotion:** none
- **Result record:** `docs/agent_council/results/iteration_002_revision_displacement.md`

## Inherited evidence

Iteration 001 showed that additional pre-reversal exposure, additional post-reversal opportunity, and the tested outcome-only attribution change did not materially improve correction. Repository inspection then established that the control learner already applies locally attributed contradiction disturbance through `CognitiveField.disturb_terminal/3`.

The first Iteration 002 specification incorrectly treated contradiction weakening as absent from C0. PR #19 recorded that blocker without changing simulation code. PR #20 corrected the design around the efficacy of the existing operation.

## Bounded question

Is the existing contradiction disturbance behaviorally ineffective because its magnitude is insufficient, because successful alternatives cannot competitively displace entrenched support, or because both changes are required together?

## Executed factorial

Paired deterministic seeds `1..100` used `90` pre-reversal ticks, `180` post-reversal ticks, and a `30`-tick restoration probe.

- **C0:** current contradiction magnitude, no competition.
- **V1:** existing contradiction operation with a fixed `2.0x` magnitude.
- **V2:** current magnitude plus finite support-conserving competition.
- **V3:** amplified magnitude plus the same competition.

No reversal flag, correct-action label, semantic prediction, reward, planner, or global causal knowledge entered learner-visible state. Default `AssociationReversalExperiment` behavior and core world physics were unchanged.

## Validation and evidence

- All six PR workflows passed.
- Focused tests and the full test suite passed.
- The workflow produced 400 rows with balanced variants and paired seeds `1..100`.
- Replay output was byte-identical.
- Workflow run: `29763736033`.
- Artifact ID: `8469889781`.
- Artifact digest: `sha256:a331f4e6abd7ebc0480888a01ef01453f0db209b25fd7dfcb31acab7b920ff10`.
- Environment: Elixir `1.14.5`, OTP `25`.

## Measured result

| Variant | Corrected | Obsolete median | Expression median | Intake median | Removed median | Recovery median | Displaced median | Restoration median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C0 | 2/100 | 0.944 | 0.972 | 0.000 | 0.114 | 0.500 | 0.000 | 0.967 |
| V1 | 2/100 | 0.944 | 0.972 | 0.000 | 0.166 | 0.500 | 0.000 | 0.967 |
| V2 | 1/100 | 0.928 | 0.967 | 0.000 | 0.100 | 0.624 | 0.114 | 0.967 |
| V3 | 1/100 | 0.928 | 0.967 | 0.000 | 0.100 | 0.545 | 0.100 | 0.967 |

Paired correction outcomes were:

- C0 to V1: `0` improved, `100` tied, `0` worsened.
- C0 to V2: `0` improved, `99` tied, `1` worsened.
- C0 to V3: `0` improved, `99` tied, `1` worsened.

## Council interpretation

V1 removed more support without changing behavior. Disturbance magnitude alone is therefore weakened as the primary explanation.

V2 and V3 displaced support and slightly lowered obsolete-action frequency, but neither improved correction. Simple finite competition is not supported as a sufficient mechanism, and no interaction is supported.

Activity and restoration remained near control, so inactivity and broad erasure do not explain the result.

The result is **inconclusive**, not a registered failure, because:

- median post-reversal intake was zero in all variants, making the intake safeguard non-informative;
- the implementation's failure classifier compared support removed with a recovery ratio, which are different units and cannot validly determine net-support significance.

The raw evidence remains valid. The classifier defect must be repaired prospectively rather than used to retune or relabel this run.

## Retained findings

- Contradiction events are occurring; total absence of eligible negative evidence is not supported.
- Doubling disturbance magnitude changes internal support but not behavior.
- Finite competition changes support balance slightly but does not improve correction.
- The unresolved boundary is now between internal support revision, action-selection translation, and scenario/metric adequacy.
- No architecture is promoted.

## Handoff

Iteration 002 is closed. The persistent council advances to Iteration 003 evidence review.

Iteration 003 should prospectively repair net-support and intake measurement semantics and distinguish whether support changes fail to influence action selection or whether the current scenario cannot meaningfully evaluate useful revision. It must preserve the entity's information boundary and must not retune Iteration 002 after observing its results.
