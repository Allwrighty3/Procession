# Procession Experimental Council

## Purpose

The Experimental Council is a disciplined review forum for turning an uncertainty about Procession's simulations into one bounded, falsifiable experiment specification. It exists to prevent attractive explanations, test assertions, metric output, and architectural decisions from being mistaken for one another.

The council complements [`docs/simulation/`](../simulation/), which records simulation models, findings, and experiment-specific constraints, and [`docs/model_training/`](../model_training/), which governs model-training data, export, review, and runtime boundaries. It does not replace either body of work. Model-training data and review tools are not developmental teaching experiments unless repository evidence explicitly establishes that role.

## What the council is and is not

The council is an adversarial specification and evidence-review process. It may inspect repository evidence, debate competing explanations, and recommend a single bounded experiment with controls and falsifiers.

It is not an autonomous implementation authority, a source of scientific truth, a replacement for tests or measurements, a mechanism for inferring hidden entity experience, or a way to elevate chat recollection over committed evidence.

## Required adversarial roles

Every council review must include these roles:

- **Learner Advocate** — asks whether the learner organization, revision capacity, or local learning substrate is an adequate explanation.
- **Teacher and Environment Advocate** — tests whether exposure, caregiver guidance, task structure, or environmental opportunity better explains the outcome.
- **Emergence Guardian** — protects against authored shortcuts and claims that emergence occurred when the relevant information was supplied directly.
- **Measurement Skeptic** — challenges metrics, controls, seed coverage, confounds, and interpretation.
- **OTP and Architecture Guardian** — protects Elixir/OTP authority, validation boundaries, behavior-as-data, and blueprint-versus-live-process distinctions.
- **Adjudicator** — records disagreements, confirms the evidence class of each claim, and produces the bounded recommendation or an explicit inconclusive result.

## Current authority level

**Level 1 — report and specification only.**

The council may inspect, debate, and recommend one bounded experiment. It may not modify simulation code unless a later registry decision explicitly grants Level 2 authority.

## Escalation conditions

A request may seek a later authority decision only when the council record identifies a bounded hypothesis, falsifying result, controls and variants, exact seeds, constraint audit, measurement plan, and reviewable implementation boundary. Escalation must also show that the proposed mechanism does not expose coordinates, hidden state, named correct actions, semantic rewards, reversal flags, or causal explanations to entities; bypass Elixir validation; or silently promote an experimental mechanism into core architecture.

A failing or inconclusive result is not by itself grounds for escalation. Neither a passing test nor a committed metric document is architectural promotion.

## Evidence over chat memory

The repository is authoritative over chat memory. A council statement must be traceable to committed implementation, test assertions, executed output, CI artifacts, or committed result documentation, with its evidence class recorded. If chat memory conflicts with the current branch, repository evidence wins; if the evidence is absent or ambiguous, the council records the claim as unverified rather than filling the gap with recollection.

See [the evidence protocol](evidence_protocol.md) and [the initial registry](experiment_registry.md).
