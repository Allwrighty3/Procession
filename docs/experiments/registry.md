# Experiment Registry

Procession keeps experiments as reproducible evidence without making every historical investigation part of normal CI.

## Policy

- `active`: protects current simulation behavior and may run automatically with narrow `paths` filters.
- `manual`: useful, reproducible evidence that runs only through GitHub Actions `workflow_dispatch` or its Mix task.
- `archived`: result is retained for reference; implementation and tests remain in the repository, but it is not a routine development gate.
- Primary CI owns the shared compile and full-suite test pass. Experiment workflows should not be used as duplicate general CI.

## Primary validation

| Capability | Status | Automatic | Command |
|---|---|---:|---|
| Project compile and full test suite | active | yes | `mix compile --warnings-as-errors && mix test` |

## Manual legacy experiments

| Experiment | Status | Workflow | Reproduction command |
|---|---|---|---|
| Bounded cognition | manual | `bounded-cognition.yml` | `mix procession.metrics.bounded_cognition` |
| Learner-owned/fading assistance | manual | `fading-assistance.yml` | `mix procession.metrics.learner_owned_assistance --population 48 --stage-ticks 40 --withdrawal-ticks 100 --seed 1` |
| Fading-assistance survivor trace | manual | `fading-assistance-survivor-trace.yml` | `mix run -e 's = Procession.Simulation.FadingAssistanceSurvivorTrace.run(population: 48, stage_ticks: 40, withdrawal_ticks: 100, seed: 1); IO.puts(Procession.Simulation.FadingAssistanceSurvivorTrace.report(s))'` |
| Home-foraging contingency | manual | `home-foraging-contingency.yml` | `mix procession.metrics.home_foraging_contingency --population 24 --seed 1` |
| Home-foraging ungrounded control | manual | `home-foraging-ungrounded-control.yml` | `mix procession.metrics.home_foraging_ungrounded_control --population 24 --seed 1 --ticks 8000` |
| Home-foraging pressure control | manual | `home-foraging-pressure-control.yml` | `mix procession.metrics.home_foraging_pressure_control --population 24 --seed 1` |
| Home-foraging seed replication | manual | `home-foraging-seed-replication.yml` | `mix procession.metrics.home_foraging_seed_replication --population 24 --seeds 101,211,307,401,503` |
| Home-foraging memory audit | manual | `home-foraging-memory-audit.yml` | `mix run -e 'result = Procession.Simulation.HomeForagingMemoryAudit.run(population: 48, stage_ticks: 40, withdrawal_ticks: 120, seed: 1); IO.puts(Procession.Simulation.HomeForagingMemoryAudit.report(result))'` |
| Relational terrain prototype | manual | `relational-terrain.yml` | Run the focused relational-terrain tests and the `procession.metrics.relational_terrain_*` tasks listed in the workflow. |
| Trajectory landscape | manual | `trajectory-landscape.yml` | `mix procession.metrics.trajectory_landscape --repetitions 40 --idle-ticks 80` |
| Obsolete-path/action-cost reversal | archived | `obsolete-path-balance.yml` | `mix procession.metrics.action_cost_reversal --seeds 100` |

## Adding or retiring experiments

1. Start with a focused Mix task and focused tests.
2. Add automatic execution only when the result protects a current invariant.
3. Use narrow `paths` filters for active experiments.
4. Once an investigation has answered its question, switch its workflow to `workflow_dispatch` and record the command and conclusion here.
5. Do not delete useful experiment code merely because it no longer runs automatically.
