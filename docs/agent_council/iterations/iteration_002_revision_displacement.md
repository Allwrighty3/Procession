# Iteration 002: Contradiction Weakening and Competitive Displacement

## Identity

- **Iteration:** 002
- **Council:** Procession Experimental Council
- **Inherited state:** `docs/agent_council/council_state.md`
- **Phase:** blocked
- **Authority level:** Level 2 was considered for the specified implementation boundary, but implementation is blocked pending re-specification
- **Previous result:** Iteration 001 revision-opportunity and attribution factorial, executed by GitHub Actions on commit `71f9b9c26a5c00a441c9f6f50b043be0865ec12b`

## Evidence loaded

The council originally reviewed:

- the Iteration 001 factorial implementation and tests;
- the retained GitHub Actions artifact containing 400 primary rows and 400 byte-identical replay rows;
- paired deterministic seeds `1..100` for C0, V1, V2, and V3;
- the measured correction rates: C0 `2/100`, V1 `2/100`, V2 `0/100`, and V3 `4/100`;
- post-reversal obsolete-action rates remaining approximately `0.93` to `0.97` by variant median;
- zero disagreement between behavioral and resistance classifications;
- the persistent council state created after Iteration 001.

Before implementation, repository inspection additionally reviewed:

- `lib/procession/simulation/association_reversal_experiment.ex`;
- `lib/procession/simulation/cognitive_field.ex`;
- `lib/procession/simulation/revision_opportunity_attribution_factorial_experiment.ex`.

## Pre-implementation finding

The specified control-versus-treatment distinction is invalid as written.

The current association-reversal learner already performs local contradiction-sensitive weakening. Delayed effects retain the executed action, activation flow, local action/displacement trace keys, actual local intake change, and experienced change. When the experienced change is negative and local attribution remains active, the learner calls `CognitiveField.disturb_terminal/3` on the active action path with a locally scaled contradiction magnitude.

Therefore:

- C0 is not a learner with no contradiction weakening;
- V1 cannot introduce contradiction-sensitive weakening as a novel mechanism without misdescribing the existing substrate;
- implementing V1 as stronger weakening would test magnitude or targeting, not presence versus absence of contradiction weakening;
- implementing a new semantic expected-continuation model would exceed the authorized boundary and risk manufacturing the missing information.

No simulation code was changed after this finding.

## Standing-role re-review

### Learner Advocate

The current learner has a revision operation, but Iteration 001 suggests it is behaviorally ineffective. The next question should distinguish whether the operation is too weak, too transient, poorly attributed, or unable to compete with continuing reinforcement.

### Teacher and Environment Advocate

The environment already supplies negative local consequences after reversal. More exposure did not help, so the next experiment should inspect how existing negative evidence changes retained support rather than add a new teaching signal.

### Emergence Guardian

A new semantic prediction or explicit mismatch representation must not be introduced solely to make contradiction detectable. The existing delayed local consequence and active trace are the permissible information boundary.

### Measurement Skeptic

The original V1 label would falsely imply mechanism introduction. A revised design must measure the existing contradiction operation directly: number of eligible negative effects, disturbance magnitude applied, support removed, later reinforcement of the same path, and net retained support.

### OTP and Architecture Guardian

Stopping before implementation is correct. The isolated experiment boundary does not authorize changes to the default learner or invention of a new expectation subsystem.

### Adjudicator

Iteration 002 remains active but blocked. The council must re-specify the factorial around the mechanism that actually exists.

## Original specification status

The following original comparison is retired:

- C0 current versus V1 newly introduced contradiction weakening.

Competitive displacement remains a viable candidate, but it should not be compared against a falsely characterized control.

## Required re-specification

The same council should revise Iteration 002 around one of these bounded distinctions:

1. **Contradiction efficacy:** current disturbance versus increased bounded disturbance versus persistence-adjusted disturbance, while measuring whether later reinforcement immediately restores obsolete support.
2. **Evidence balance:** current contradiction disturbance versus finite competition that transfers a bounded portion of new successful support away from the locally competing obsolete alternative.
3. **Net revision accounting:** current behavior versus a treatment that changes only the balance between locally applied disturbance and ordinary subsequent reinforcement, without adding new learner-visible information.

The preferred next design should preserve C0 exactly and describe V1 as a modification of existing contradiction efficacy, not introduction of contradiction itself.

## Implementation record

- **Attempted action:** inspect the authorized implementation boundary before modifying code.
- **Result:** blocked by mismatch between the specification and existing implementation.
- **Simulation files changed:** none.
- **Tests run:** none required for this documentation-only block record; GitHub Actions on the resulting PR is authoritative.
- **Architectural promotion:** none.

## Measured result

Unmeasured. No Iteration 002 factorial was implemented or executed.

## State handoff

Iteration 002 remains the active iteration at phase `blocked`. Resume from the specification phase after the standing council redefines C0/V1/V2/V3 using the existing contradiction operation as repository fact. Do not create Iteration 003 and do not create a new council for this correction.
