# Experimental Council State

This file is the durable handoff between council iterations. The Experimental Council is one persistent development process; numbered iterations are successive cycles of the same council, not newly created councils.

## Current cycle

- **Last completed iteration:** 001
- **Active iteration:** 002
- **Current phase:** specified
- **Active question:** Is the existing contradiction disturbance ineffective because its magnitude is insufficient, because later reinforcement restores obsolete support, or because successful alternatives cannot competitively displace entrenched support?
- **Current authority:** Level 1 corrected specification only; Level 2 implementation has not yet been granted
- **Architectural promotions:** none
- **Current specification:** `docs/agent_council/iterations/iteration_002_revision_displacement.md`

## Retained findings

- Iteration 001 executed 100 paired seeds across C0, V1, V2, and V3.
- Additional post-reversal opportunity did not materially improve behavioral correction.
- Additional pre-reversal exposure did not improve correction.
- The tested outcome-only attribution variant did not produce a meaningful recovery.
- Behavioral and resistance classifications agreed; measurement disagreement did not explain the result.
- The registered failure criterion was met.
- The existing association-reversal learner already applies contradiction-sensitive terminal disturbance after a locally attributed negative experienced effect.
- The original Iteration 002 specification incorrectly treated contradiction weakening as absent from C0.
- PR #19 recorded the blocker and confirmed that no simulation implementation was made under the invalid design.
- Iteration 002 has now been re-specified around the efficacy and net persistence of the existing disturbance operation.

## Unresolved explanations

1. Existing contradiction disturbance may be too weak to offset accumulated support.
2. Disturbed obsolete support may be rapidly restored by ordinary subsequent reinforcement.
3. Local attribution decay may make too few negative effects eligible for meaningful disturbance.
4. Successful competing activity may be unable to displace entrenched support.
5. Amplified disturbance and finite competition may interact.
6. All treatments may fail because the learner lacks a more general revision process.

## Corrected bounded design

Paired seeds `1..100` use an unchanged world and entity-visible stream:

- **C0:** current contradiction magnitude, no competition;
- **V1:** existing contradiction operation with fixed `2.0x` bounded magnitude;
- **V2:** current magnitude plus finite support-conserving local competition;
- **V3:** amplified magnitude plus the same finite competition.

The experiment directly measures eligible negative effects, support removed, same-path reinforcement during a five-tick recovery window, net retained support, competing deposits, and displaced support. A restoration probe and activity/intake safeguards prevent broad erasure or inactivity from being counted as revision.

## Retired assumptions

- Contradiction-sensitive weakening is not absent from C0.
- No semantic expected-continuation model may be added.
- V1 tests magnitude of the existing operation, not introduction of a new mechanism.

## Next council action

Review the corrected specification and decide whether to grant Level 2 authority for its exact implementation boundary. If authorized, implement only the isolated factorial, experiment-local accounting/update helpers, metrics task, focused tests, retained evidence workflow, and iteration documentation updates. Do not modify default learner behavior or promote architecture.

## State update rule

At the close of every iteration, update this file with:

- completed iteration number and evidence location;
- active phase and next iteration number;
- findings retained as evidence;
- explanations rejected, weakened, strengthened, or still unresolved;
- explicit architectural decisions;
- the single next council action.

Do not replace prior result documents with this summary. Result documents preserve history; this file carries only the current development state forward.
