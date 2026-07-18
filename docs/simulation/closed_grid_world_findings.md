# Closed 4x4 embodied world findings

## World

The experiment uses a 4x4 grid, three regenerating resource points, finite entity
energy, metabolic drain, movement expenditure, fatigue, recovery, persistent motor
channels, local resource gradients, and seeded lower-level fluctuations.

The entity receives no target coordinate, route, survival score, or causal
explanation. Resource intake reduces maintenance pressure through ordinary energy
replenishment.

Two motor controls are compared:

- `:fatigue_only`
- `:conditional_refractory`, which suppresses only failed or locally harmful output

## Limited-regeneration population run

Command:

```bash
mix procession.metrics.closed_grid_world --samples 100 --ticks 320
```

Resource regeneration per tick was `0.004`, `0.003`, and `0.005`, forcing movement
between resource sites rather than permitting indefinite camping at one node.

Validated results:

```text
fatigue_only: survived=100 lifetime=320.000 energy=0.227 intake=2.969 rest=0.972 visits=3.000 failed=0.000 harmful=0.000 resource_distance=4.000
conditional_refractory: survived=100 lifetime=320.000 energy=0.227 intake=2.969 rest=0.972 visits=3.000 failed=0.000 harmful=0.000 resource_distance=4.000
```

## Interpretation

The closed loop changes the meaning of inactivity. Entities survive, visit all three
resource nodes, consume resources, and spend long periods recovering or waiting for
regeneration. Rest is therefore no longer automatically a motor failure.

The first generous resource configuration allowed permanent camping at one node.
Reducing regeneration forced population-wide multi-resource use while preserving
survival.

Conditional refractory suppression made no difference because the local gradients
produced no failed boundary outputs and no movements that increased distance from
available resources. The mechanism remained dormant rather than punishing successful
behavior.

The world is still simple. The 97.2% rest fraction and final distance from an available
resource show that resource regeneration timing dominates the behavior. Useful next
extensions include partial or noisy perception, temporary occlusion, resource quality
variation, and maintenance dimensions with different resources. Those additions can
make locally reasonable actions occasionally fail without supplying an authored
exploration policy.
