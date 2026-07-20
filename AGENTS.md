# Procession Agent Instructions

## Project identity

Procession is an experimental single-player RPG simulation engine built around Elixir/OTP. It is Elixir/OTP-first: Elixir owns live simulation state, behavior validation and execution, world ticks, entity processes, memory, gameplay state, supervision, and message passing.

## Architecture boundaries

- Treat AI-generated proposals, content, and data as non-authoritative until Elixir-side validation accepts them.
- Keep behavior metadata as data with a safe, validated vocabulary; do not generate or execute arbitrary behavior code.
- Preserve the boundary between inert blueprints, summaries, persisted records, and live OTP processes. Spawning is an explicit transition, not an implication of generation.
- Preserve the future world shape: do not assume a flat world, a fully spawned world, or one-pass generation.
- Keep specialized or offline tools outside ownership of live state and gameplay decisions.

## Working priorities

1. Preserve architectural boundaries and safety invariants.
2. Make the smallest bounded change that supplies observable value.
3. Prefer deterministic, testable evidence over persuasive narrative.
4. Keep experimental mechanisms isolated until an explicit architectural promotion decision.
5. Keep documentation, tests, and implementation claims aligned.

## Protected constraints

- Never expose coordinates, hidden state, named correct actions, semantic rewards, reversal flags, or causal explanations to simulated entities.
- Keep observer-only diagnostics and evaluation labels outside entity-visible state.
- Never weaken tests to obtain a pass.
- Never claim behavioral support merely because tests pass.
- Use terms such as learner, teacher, suffering, and compression only where repository evidence supports the usage. Do not describe structural stress as cognitive suffering, FlowLearning as a full independent learner, or model-training/review tooling as developmental teaching experiments.

## Experimental workflow

1. Read the relevant implementation, tests, metrics tasks, committed findings, and CI evidence before proposing a change.
2. Record a bounded hypothesis, falsifying result, controls, variants, seed set, commands, environment, measurement method, and constraint audit in the experiment record.
3. Distinguish implementation existence, assertions, executed runs, metrics, artifacts, result documents, interpretations, and promotion decisions; they are not interchangeable evidence.
4. Keep experiment-only code and measurements non-authoritative. Do not silently promote experimental mechanisms into core architecture.
5. Follow `docs/agent_council/evidence_protocol.md` for new council work.

## Branch and pull-request rules

- Never commit directly to `main`.
- Create one task branch per bounded change.
- Do not merge branches or pull requests.
- Keep each pull request reviewable, focused, and explicit about evidence and limitations.

## Evidence and validation requirements

- Run focused tests and `mix test` when the environment permits.
- Report environmental restrictions that prevent validation; do not present blocked checks as passing.
- Record exact commands, exact seeds, and raw-output locations for executed experiments.
- Separate measured results from interpretation and from any architectural recommendation.

## Forbidden shortcuts

- Do not bypass behavior validation, dynamically create atoms from generated input, or execute generated content before validation.
- Do not turn blueprints into live processes merely for convenience.
- Do not replace Elixir ownership of live state with an AI, external service, client, or offline tool.
- Do not invent metrics, results, causal explanations, or authority that repository evidence does not establish.

## Completion requirements

Before declaring work complete, ensure the bounded change is documented, focused checks have been attempted when permitted, limitations are reported, and `git diff`/`git status` are reviewed. Commit only on the task branch, prepare the change for review, and do not merge.
