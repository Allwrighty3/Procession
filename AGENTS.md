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

## Codex environment bootstrap

- From the repository root, run `bash scripts/codex_setup.sh` before implementation when dependencies are not already available.
- The setup script installs Hex and Rebar noninteractively, fetches and compiles dependencies, and runs `mix compile --warnings-as-errors` under `MIX_ENV=test` by default.
- Internet access is expected during setup for Hex and GitHub dependency retrieval. If access fails, record the exact command and error rather than substituting isolated stubs for project validation.
- Do not modify dependencies, lockfiles, or workflow configuration merely to accommodate a restricted agent environment unless the task explicitly authorizes that change.

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
- Before editing an existing PR, verify the actual remote PR head and work from that branch or commit. Do not assume the task checkout contains the latest PR state.
- Update the existing PR rather than creating a replacement PR unless explicitly authorized.
- A local commit is not published evidence. Confirm that the remote PR head changed and that a new GitHub Actions run was scheduled.
- Treat GitHub Actions as authoritative for repository-wide validation. Local or isolated compilation may diagnose syntax, but it does not replace project compilation or ExUnit execution.

## Evidence and validation requirements

- Run `mix compile --warnings-as-errors` after setup.
- Run the narrowest relevant test file first, then run `mix test` for repository-wide validation when the change can affect shared behavior.
- Report exact test counts and failures from the actual command or GitHub Actions output.
- Report environmental restrictions that prevent validation; do not present blocked checks as passing.
- Record exact commands, exact seeds, and raw-output locations for executed experiments.
- Separate measured results from interpretation and from any architectural recommendation.

## Forbidden shortcuts

- Do not bypass behavior validation, dynamically create atoms from generated input, or execute generated content before validation.
- Do not turn blueprints into live processes merely for convenience.
- Do not replace Elixir ownership of live state with an AI, external service, client, or offline tool.
- Do not invent metrics, results, causal explanations, or authority that repository evidence does not establish.

## Completion requirements

Before declaring work complete:

1. Ensure the bounded change is documented.
2. Run or attempt the setup, compilation, focused tests, and full suite as appropriate.
3. Review `git diff --check`, the final diff, and `git status`.
4. Commit only on the task branch and publish the commit to the intended remote branch.
5. Verify the PR head and CI run on GitHub.
6. Report limitations accurately and leave the PR unmerged for review.
