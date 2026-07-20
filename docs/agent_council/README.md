# Procession Experimental Council

## Purpose

The Experimental Council is Procession's persistent, recurring process for turning unresolved development questions into bounded experiments, reviewing the resulting evidence, and selecting the next development direction. Numbered iterations are successive cycles of the same council, not newly created councils.

The council exists to prevent attractive explanations, test assertions, metric output, and architectural decisions from being mistaken for one another. It complements [`docs/simulation/`](../simulation/) and [`docs/model_training/`](../model_training/); it does not replace either body of work.

## Persistent operation

The council repeatedly:

1. loads the current council state and prior evidence;
2. convenes the same adversarial roles;
3. develops competing explanations;
4. selects one bounded question;
5. specifies and authorizes an experiment;
6. reviews retained measurements;
7. updates the durable state;
8. begins the next iteration.

There is no planned final council iteration that permanently determines all future development. The process continues while it remains useful and may pause without dissolving. A new experiment does not create a new council.

The durable handoff is [`council_state.md`](council_state.md). The full recurring process is defined in [`iteration_lifecycle.md`](iteration_lifecycle.md), and new cycles use [`iteration_template.md`](iteration_template.md).

## What the council is and is not

The council is an adversarial specification, evidence-review, and development-direction process. It may inspect repository evidence, debate competing explanations, recommend a bounded experiment, adjudicate measured results, and carry unresolved questions into the next cycle.

It is not a source of scientific truth, a replacement for tests or measurements, a mechanism for inferring hidden entity experience, or a way to elevate chat recollection over committed evidence. It does not receive unlimited implementation authority merely because a new iteration begins.

## Required adversarial roles

Every council iteration must include these standing roles:

- **Learner Advocate** — asks whether learner organization, revision capacity, or the local learning substrate explains the evidence.
- **Teacher and Environment Advocate** — tests whether exposure, caregiver guidance, task structure, or environmental opportunity better explains the outcome.
- **Emergence Guardian** — protects against authored shortcuts and claims that emergence occurred when relevant information was supplied directly.
- **Measurement Skeptic** — challenges metrics, controls, seed coverage, confounds, and interpretation.
- **OTP and Architecture Guardian** — protects Elixir/OTP authority, validation boundaries, behavior-as-data, and blueprint-versus-live-process distinctions.
- **Adjudicator** — records disagreements, confirms evidence classes, selects the bounded next question, and closes the iteration with a durable handoff.

The roles remain stable across iterations. Their conclusions may change when evidence changes.

## Authority

The standing council begins each new question at **Level 1 — report and specification only** unless the experiment registry or an explicit decision grants a narrowly bounded Level 2 implementation authority.

Authority attaches to a named experiment and implementation boundary, not to the council forever. Starting Iteration 002 does not inherit unrestricted authority from Iteration 001.

A request may seek Level 2 authority only when the council record identifies a bounded hypothesis, falsifying result, controls and variants, exact seeds, constraint audit, measurement plan, and reviewable implementation boundary. The proposed mechanism must not expose coordinates, hidden state, named correct actions, semantic rewards, reversal flags, or causal explanations to entities; bypass Elixir validation; or silently promote an experimental mechanism into core architecture.

A failing or inconclusive result is not by itself grounds for escalation. Neither a passing test nor a committed metric document is architectural promotion.

## Evidence over chat memory

The repository is authoritative over chat memory. A council statement must be traceable to committed implementation, test assertions, executed output, CI artifacts, or committed result documentation, with its evidence class recorded.

If chat memory conflicts with the current branch, repository evidence wins. If evidence is absent or ambiguous, the council records the claim as unverified rather than filling the gap with recollection.

At the close of every iteration, the council must update:

- its iteration result document;
- [`experiment_registry.md`](experiment_registry.md);
- [`council_state.md`](council_state.md).

This lets the next cycle continue development directly from retained evidence instead of rebuilding context manually.

See [the evidence protocol](evidence_protocol.md), [the experiment registry](experiment_registry.md), and [the recurring iteration lifecycle](iteration_lifecycle.md).