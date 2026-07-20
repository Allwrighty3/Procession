# Iteration 002: Existing Contradiction Efficacy and Competitive Displacement

## Identity

- **Iteration:** 002
- **Council:** Procession Experimental Council
- **Inherited state:** `docs/agent_council/council_state.md`
- **Phase:** specified
- **Authority level:** Level 1 specification only; Level 2 implementation requires explicit authorization
- **Previous result:** Iteration 001 revision-opportunity and attribution factorial
- **Design-block record:** PR #19 established that the existing control already applies locally attributed contradiction disturbance

## Evidence loaded

The council reviewed:

- the retained Iteration 001 evidence over paired seeds `1..100`;
- correction rates C0 `2/100`, V1 `2/100`, V2 `0/100`, and V3 `4/100`;
- post-reversal obsolete-action medians near `0.93` to `0.97`;
- zero behavioral/resistance classification disagreement;
- `AssociationReversalExperiment`, including delayed local effects, trace-scaled attribution, ordinary reinforcement, and `contradict/7`;
- `CognitiveField.disturb_terminal/3`, which removes residue and increases decay on the selected terminal transition;
- the PR #19 finding that contradiction-sensitive weakening already exists in C0.

Repository evidence establishes that the missing question is not whether contradiction weakening exists. The unresolved question is why its net effect is behaviorally negligible.

## Standing role views

### Learner Advocate

- **Supported explanation:** contradiction disturbance may remove too little support relative to entrenched residue and later deposits.
- **Alternative:** the disturbance may be locally effective but ordinary positive reinforcement rapidly restores the same obsolete path.
- **Distinguishing evidence:** measure disturbance events, support removed, same-path reinforcement after disturbance, and net retained support—not only final behavior.

### Teacher and Environment Advocate

- The world already produces negative local consequences after reversal, and longer exposure did not improve revision.
- The environment and entity-visible stream must remain unchanged. This iteration should vary only the internal balance applied to already available local evidence.

### Emergence Guardian

- No reversal flag, correct action, named obsolete pathway, semantic punishment, or explicit prediction model may be added.
- Eligible disturbance must continue to arise only from the existing delayed experienced delta and locally active action/displacement traces.
- Competition may use only ordinary successful local reinforcement and the simultaneously available alternatives in the same local choice context.

### Measurement Skeptic

- Increased disturbance can appear successful through broad erasure or inactivity.
- Competition can appear successful by reducing all support rather than transferring relative dominance.
- Required diagnostics include eligible negative effects, applied disturbance, residue removed, same-path reinforcement within a fixed recovery window, competing deposits, support displaced, action rate, intake, correction, obsolete-action rate, and restoration-probe reuse.

### OTP and Architecture Guardian

- Elixir remains authoritative over state, deterministic execution, validation, and evidence generation.
- All changes must remain inside an isolated experiment wrapper and experiment-local support-update functions.
- Default learner behavior and core world physics must remain unchanged.

### Adjudicator

- **Selected bounded question:** Is the current contradiction disturbance behaviorally ineffective because its magnitude is insufficient, or because successful alternatives cannot competitively displace entrenched support; and does amplified disturbance interact with finite competition?
- **Deferred question:** explicit persistence/refractory changes are deferred. Same-path reinforcement recovery will be measured first rather than adding another stateful mechanism.
- **Retired framing:** no variant may be described as introducing contradiction-sensitive weakening.

## Revised factorial specification

### Variants

- **C0 — current balance:** current local-adaptive learner, current contradiction magnitude, no competitive displacement.
- **V1 — amplified existing disturbance:** identical to C0 except the existing contradiction magnitude is multiplied by a fixed bounded factor of `2.0`. Eligibility, targeting, and learner-visible information remain unchanged.
- **V2 — finite competitive displacement:** current contradiction magnitude plus finite competition. When ordinary positive reinforcement is deposited on one active alternative, transfer at most `25%` of that deposit by removing no more than the transferred amount from other currently active alternatives in the same local choice context. No support is created by competition.
- **V3 — combined:** amplified existing disturbance plus the same finite competitive displacement rule.

### Fixed conditions

- Existing association-reversal world and schedule.
- `90` pre-reversal ticks and `180` post-reversal ticks, followed by a `30`-tick restoration probe.
- Same sensory channels, action availability, attribution mode, coincidence process, initial field, trace behavior, and entity-visible stream.
- Paired deterministic seeds `1..100` across all four variants.
- Variant parameters fixed before execution; no result-driven tuning.

### Net-revision accounting

For every disturbance event, observer-only diagnostics must record:

- tick and locally attributed action key;
- attribution scale;
- requested and actual residue removed;
- transition residue immediately before and after disturbance;
- positive reinforcement deposited on that same transition during the next `5` ticks;
- residue at the end of that recovery window.

For competition, diagnostics must record:

- successful deposit before competition;
- competing active alternatives;
- support removed from each competitor;
- total displaced support;
- conservation check showing displaced support never exceeds the successful deposit fraction.

These records are observer diagnostics. They are not supplied to action selection or learner state beyond the authorized local update itself.

## Measurements

- Behavioral correction rate and delay using the existing sliding `30`-tick definition.
- Resistance correction rate and delay.
- Normalized obsolete-action rate.
- Activity/expression rate and intake.
- Eligible negative-effect count.
- Disturbance event count and total support removed.
- Five-tick same-path reinforcement recovery ratio.
- Net support change after recovery windows.
- Successful competing deposits and total support displaced.
- Per-action support at pre-reversal end, post-reversal end, and restoration end.
- Restoration-probe recovery.
- Behavioral/resistance agreement.

## Registered criteria

### Success

At least one treatment must satisfy all of the following relative to paired C0:

- behavioral correction improves in at least `20/100` seeds and worsens in no more than `10/100`;
- median normalized obsolete-action rate decreases by at least `0.15`;
- median activity and intake each remain within `10%` of C0;
- restoration-probe recovery remains within `20%` of C0;
- deterministic replay is byte-identical.

### Mechanism distinction

- **Magnitude-supported:** V1 materially outperforms C0 while V2 does not.
- **Competition-supported:** V2 materially outperforms C0 while V1 does not.
- **Interaction-supported:** V3 materially outperforms both V1 and V2 under all safeguards.
- **Reinforcement-recovery evidence:** treatment produces larger immediate support removal but the five-tick recovery ratio restores at least `75%` of removed support and behavioral correction does not improve.

“Materially outperforms” means at least `15` more paired improvements than worsenings and at least `0.10` lower median obsolete-action rate.

### Failure

Failure is met when all treatments:

- improve behavioral correction in fewer than `10/100` paired seeds;
- reduce median obsolete-action rate by less than `0.05`;
- and produce no meaningful net-support change after recovery accounting.

### Inconclusive

The result is inconclusive if:

- apparent improvement is explained by inactivity, intake collapse, or broad erasure;
- support accounting or conservation fails;
- paired pre-update world histories diverge;
- deterministic replay fails;
- fewer than 100 valid paired seeds remain;
- or behavioral outcomes improve while restoration safeguards fail.

## Falsifiers and safeguards

- C0 must reproduce current learner behavior without an experiment-local update change.
- V1 may change magnitude only—not eligibility, attribution, targeting, or semantics.
- V2/V3 competition must be finite and support-conserving.
- No observer label may enter learner-visible state.
- Pre-update action choices and world effects must be identical across paired variants until their authorized update rules produce state divergence.
- Lower obsolete behavior through inactivity is not correction.
- Broad loss of previously useful support is not revision.

## Authorized boundary if Level 2 is granted

- one isolated `RevisionDisplacementFactorialExperiment` module;
- experiment-local update/accounting helpers;
- one deterministic JSONL Mix task;
- focused ExUnit tests;
- one dedicated/manual GitHub Actions evidence workflow;
- iteration-specific registry, result, and council-state updates.

Forbidden changes:

- modifying default `AssociationReversalExperiment` behavior for ordinary callers;
- changing core world physics;
- adding semantic predictions, rewards, reversal flags, correct-action labels, planners, or global causal knowledge;
- modifying unrelated experiments;
- claiming architectural promotion.

## Required tests

- option and mode validation;
- C0 equivalence with the existing local-adaptive baseline;
- paired world-stream equivalence before update divergence;
- observer-field isolation;
- V1 changes magnitude only;
- finite competition conservation and local-choice scoping;
- support-removal and recovery accounting;
- activity/intake safeguards;
- restoration probe;
- exact 400-row schema and seed coverage;
- byte-identical repeated output;
- full test suite.

## Implementation handoff

Implement the revised factorial as an isolated wrapper around the current association-reversal substrate. Preserve C0 exactly. Instrument the existing contradiction operation rather than replacing it. Add only the fixed amplified-magnitude treatment and finite local competition described above. Produce 400 deterministic rows plus an identical replay, aggregate summary, focused tests, full-suite validation, and a retained workflow artifact. Do not change the default learner or claim promotion.

## Execution record

Not yet executed. The corrected Iteration 002 design is specified but not yet authorized for implementation.

## Measured result

Unmeasured.

## State handoff

Iteration 002 is active at phase `specified`. The next action is an explicit Level 2 authorization decision for this corrected implementation boundary.