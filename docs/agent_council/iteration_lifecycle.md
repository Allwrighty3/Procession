# Recurring Council Iteration Lifecycle

The Experimental Council is a stable, recurring development process. A numbered iteration is one pass through this lifecycle using the evidence and unresolved questions left by the prior pass.

## Lifecycle

1. **Load state**
   - Read `council_state.md`, the experiment registry, the previous iteration result, and relevant implementation/tests.
   - Treat repository evidence as authoritative.

2. **Convene the standing roles**
   - Learner Advocate
   - Teacher and Environment Advocate
   - Emergence Guardian
   - Measurement Skeptic
   - OTP and Architecture Guardian
   - Adjudicator

3. **Produce competing explanations**
   - Each role states what the evidence supports, what it does not support, and what would distinguish its explanation from alternatives.
   - Disagreement is retained rather than prematurely averaged away.

4. **Select one bounded question**
   - Choose the question with the greatest expected development value that can be tested without violating protected constraints.
   - Record why other candidate questions were deferred.

5. **Specify the experiment**
   - Define control, variants, seeds, measurements, success/failure/inconclusive criteria, falsifiers, observer-only data, implementation boundary, and required CI evidence.
   - The experiment may vary learner mechanisms or environment conditions only when that variable is explicitly under study.

6. **Authorize implementation**
   - Authority applies only to the named experiment and files.
   - No architectural promotion occurs at authorization.

7. **Execute and retain evidence**
   - Run focused tests, the full suite, and the authorized experiment in the authoritative environment.
   - Retain raw output, summary, commit SHA, environment metadata, and deterministic-replay evidence when applicable.

8. **Adjudicate results**
   - Re-run all standing roles against the measured evidence.
   - Mark each registered criterion met, unmet, or unmeasured.
   - Separate facts, interpretation, uncertainty, and architectural decisions.

9. **Close and hand off**
   - Commit the iteration result.
   - Update the experiment registry.
   - Update `council_state.md` with retained findings and the next unresolved question.
   - Increment the iteration number and return to step 1.

## Phase states

Every iteration must be in exactly one phase:

- `convening`
- `specified`
- `authorized`
- `implementing`
- `running`
- `measured`
- `reviewed`
- `closed`
- `blocked`

A blocked iteration may resume from its prior phase. It does not require a new council or a new iteration number unless the bounded question changes materially.

## Continuity rules

- The same council roles and governance persist across all iterations.
- A new experiment does not create a new council.
- Failed and inconclusive results advance development by narrowing explanations.
- Normal implementation work may occur within an authorized iteration; the council need not reconvene for every commit.
- The next iteration begins from retained state, not from a fresh chat prompt or reconstructed memory.
- Iterations continue while the council process remains useful; there is no planned final council iteration that permanently decides all future development.

## Stop and pause conditions

The council loop pauses only when:

- the user explicitly pauses it;
- no bounded question is worth the implementation cost;
- required evidence cannot be obtained and the block is documented;
- work transitions to ordinary implementation already authorized by the current iteration.

A pause is not dissolution. The standing process resumes from `council_state.md`.