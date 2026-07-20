# Procession Development Guidance

## Project identity

Procession is an Elixir/OTP-first single-player RPG simulation. Elixir owns live simulation state, entity processes, supervision, message passing, behavior validation and execution, world ticks, memory, gameplay state, and the player-facing API.

## Architecture boundaries

- Treat AI-generated data and proposals as untrusted until Elixir-side validation accepts them.
- Keep behavior metadata as data with a validated vocabulary; never execute generated behavior code.
- Preserve the distinction between inert blueprints or summaries and live OTP processes.
- Do not assume a flat, fully spawned, or single-pass generated world.
- External tools may assist analysis, generation, or diagnostics but do not own live simulation state.

## Working priorities

1. Prefer visible, playable, or IEx-demonstrable progress.
2. Make small bounded changes with focused tests.
3. Favor practical working code over process infrastructure or abstract cleanup.
4. Keep experiments isolated until their value is demonstrated.
5. Do not expose observer-only coordinates, correct-action labels, rewards, reversal flags, or causal explanations to entities.

## Development workflow

- Inspect the relevant implementation and tests before changing code.
- Use one focused branch and pull request per meaningful change.
- Run `mix compile --warnings-as-errors`, the narrowest relevant tests, and `mix test` when shared behavior may be affected.
- Report blocked validation honestly; do not weaken tests or invent results.
- Record useful experimental findings, but do not require separate councils, authorization levels, lifecycle documents, or dedicated workflows for ordinary development.

## Direction

Procession should move toward demonstrable simulation and gameplay capability. When an experiment does not produce a useful result after a bounded attempt, preserve the finding, stop expanding its infrastructure, and return to implementation that makes the world more capable or playable.
