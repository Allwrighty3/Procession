# Iteration 002 Result: Existing Contradiction Efficacy and Competitive Displacement

## Status

- **Council iteration:** 002
- **Result:** inconclusive
- **Architectural promotion:** none
- **Workflow run:** `29763736033`
- **Artifact:** `iteration-002-revision-displacement`, ID `8469889781`
- **Artifact digest:** `sha256:a331f4e6abd7ebc0480888a01ef01453f0db209b25fd7dfcb31acab7b920ff10`
- **Artifact retention:** through 2026-10-18
- **Executed commit recorded in output:** `ba23f7865973cf740d930b0888c04e87a139dd37`
- **Environment:** Elixir `1.14.5`, OTP `25`
- **Replay:** byte-identical

## Design

The corrected 2x2 factorial used paired seeds `1..100`, `90` pre-reversal ticks, `180` post-reversal ticks, and a `30`-tick restoration probe.

- **C0:** existing contradiction magnitude, no competition.
- **V1:** fixed `2.0x` magnitude on the existing contradiction operation.
- **V2:** current magnitude plus finite support-conserving local competition.
- **V3:** amplified magnitude plus the same competition rule.

The world, entity-visible stream, action availability, initial state, attribution eligibility, and observer logic remained fixed.

## Aggregate results

| Variant | Corrected | Obsolete-action median | Expression median | Intake median | Support removed median | Five-tick recovery median | Displaced support median | Restoration original-action median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C0 | 2/100 | 0.944 | 0.972 | 0.000 | 0.114 | 0.500 | 0.000 | 0.967 |
| V1 | 2/100 | 0.944 | 0.972 | 0.000 | 0.166 | 0.500 | 0.000 | 0.967 |
| V2 | 1/100 | 0.928 | 0.967 | 0.000 | 0.100 | 0.624 | 0.114 | 0.967 |
| V3 | 1/100 | 0.928 | 0.967 | 0.000 | 0.100 | 0.545 | 0.100 | 0.967 |

Paired behavioral correction:

- C0 to V1: `0` improved, `100` tied, `0` worsened.
- C0 to V2: `0` improved, `99` tied, `1` worsened.
- C0 to V3: `0` improved, `99` tied, `1` worsened.

## Interpretation

Amplifying the existing contradiction disturbance increased median support removal from `0.114` to `0.166` but produced no behavioral change. This weakens the explanation that the existing mechanism fails only because its magnitude is too small.

Finite competition produced measurable support displacement and slightly reduced the median obsolete-action rate from `0.944` to `0.928`, but correction fell from `2/100` to `1/100`. This does not support simple finite competition as a sufficient revision mechanism.

The combined treatment did not outperform either single treatment. No interaction is supported.

The restoration metric remained stable, so the treatments did not appear to cause broad erasure. Expression also remained close to control, so inactivity does not explain the result.

## Why the result remains inconclusive

Two measurement limitations prevent registering a clean failure:

1. Median post-reversal intake is `0.000` in every variant. The intake safeguard therefore cannot meaningfully distinguish preserved useful behavior from a shared failure to obtain intake.
2. The implementation's registered failure classifier compares median support removed with median recovery ratio. These values have different units, so that calculation cannot validly determine whether net support change was meaningful.

The raw rows remain valid evidence. The invalid classifier expression must not be used to reinterpret the run as success or failure after the fact.

## Retained findings

- Existing contradiction disturbance occurs in approximately nine eligible negative-effect events per median run, so total absence of contradiction eligibility is not supported.
- Doubling disturbance magnitude changes internal support accounting without changing behavior.
- Finite competition changes support balance slightly but does not improve correction.
- Support-level change is not reliably translating into adaptive action under this scenario.
- No mechanism is promoted into default learner behavior.

## Next council direction

Iteration 003 should distinguish two remaining explanations without adding semantic knowledge:

1. learner-local support changes may not reach the action-selection dynamics strongly enough to alter behavior;
2. the current scenario and intake metric may be too degenerate to evaluate useful revision, because most runs have zero post-reversal intake.

The next iteration must repair measurement semantics prospectively and test the support-to-action translation boundary. It must not retune Iteration 002 after observing these results.
