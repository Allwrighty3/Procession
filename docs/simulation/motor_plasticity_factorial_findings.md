# Motor-Plasticity Factorial Findings

This experiment crosses two motor mechanisms with three field-plasticity profiles using the same seeds, world, learning rule, and metrics.

## Factors

Motor dynamics:

- `embodied`: accumulating fatigue with recovery
- `refractory`: stronger channel-specific temporary unavailability

Plasticity:

- `current`: `decay_slowing: 0.10`, `minimum_decay: 0.006`
- `moderate`: `decay_slowing: 0.04`, `minimum_decay: 0.025`
- `flexible`: `decay_slowing: 0.00`, `minimum_decay: 0.060`

## Validated 100-seed results

| Motor | Plasticity | Corrected | Persistent | Median delay | Median obsolete | Median active-direction switches | Median entropy |
|---|---|---:|---:|---:|---:|---:|---:|
| Embodied | Current | 25 | 75 | 91.0 | 1 | 2 | 0.482 |
| Embodied | Moderate | 28 | 72 | 91.0 | 2 | 2 | 0.481 |
| Embodied | Flexible | 29 | 71 | 91.0 | 2 | 2 | 0.481 |
| Refractory | Current | 60 | 40 | 58.0 | 1 | 3 | 0.210 |
| Refractory | Moderate | 63 | 37 | 56.0 | 1 | 3 | 0.210 |
| Refractory | Flexible | 64 | 36 | 53.5 | 1 | 3 | 0.210 |

## Main effects

Plasticity has a consistent effect in both motor conditions:

- embodied: 25 -> 29 corrected (`+4`)
- refractory: 60 -> 64 corrected (`+4`)

Refractory suppression has a much larger effect at every plasticity level:

- current: 25 -> 60 (`+35`)
- moderate: 28 -> 63 (`+35`)
- flexible: 29 -> 64 (`+35`)

Within this tested range, the effects are nearly additive and show little evidence of interaction.

## Interpretation

The current decay slowing and low minimum-decay floor do contribute to path persistence. Relaxing them improves reversal in both motor systems. However, they are not the primary source of lock-in in this controlled implementation.

The larger limitation is continued motor availability: fatigue weakens a channel but usually leaves it executable, while refractory suppression temporarily removes enough access for the competing channel to produce behavior and receive consequences.

These results do not prove the flexible profile is best globally. A higher decay floor may harm retention in stable environments. The next necessary control is retention-versus-reversal across the same 2x3 matrix.

## Reproduction

```bash
mix procession.metrics.motor_plasticity_factorial \
  --samples 100 \
  --ticks 180 \
  --reversal-tick 90
```
