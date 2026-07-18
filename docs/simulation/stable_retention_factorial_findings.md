# Stable Retention Factorial Findings

The stable retention experiment crossed the same motor dynamics and plasticity
profiles used by the reversal factorial while keeping the resource source fixed
for all 220 ticks. One hundred deterministic seeds were run per cell.

## Results

| Motor | Plasticity | Acquired | Median acquisition | Late useful | Late harmful | Late inactive | Abandonments | Useful streak |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Embodied | Current | 91 | 51.0 | 0.027 | 0.018 | 0.964 | 1 | 13.0 |
| Embodied | Moderate | 91 | 51.0 | 0.027 | 0.018 | 0.950 | 1 | 11.0 |
| Embodied | Flexible | 91 | 51.0 | 0.027 | 0.018 | 0.950 | 2 | 10.5 |
| Refractory | Current | 97 | 40.5 | 0.018 | 0.009 | 0.964 | 1 | 1.0 |
| Refractory | Moderate | 97 | 40.5 | 0.018 | 0.009 | 0.964 | 1 | 1.0 |
| Refractory | Flexible | 97 | 40.5 | 0.018 | 0.009 | 0.964 | 1 | 1.0 |

## Interpretation

The stable control does not support changing the global plasticity defaults yet.
Relaxing plasticity did not improve acquisition or late useful action in this
world. Under embodied dynamics it slightly shortened useful streaks and the
flexible profile increased median abandonment events from one to two.

Refractory suppression improved acquisition frequency and speed, but retained
useful output poorly. Its median useful streak was one tick under every
plasticity profile. It therefore appears to interrupt dominance too strongly for
a stable environment even though it helped reversal.

The dominant result is late inactivity. Every cell spent at least 95% of the
late window below the movement threshold. This means the current experiment is
not yet measuring a clean retention/adaptability tradeoff. Motor suppression and
threshold dynamics are starving the field of embodied consequences after early
acquisition.

The next experiment should vary refractory recovery and inhibition against the
movement threshold while holding the moderate field profile fixed. The target is
not maximum switching. It is a region that preserves multi-tick useful action in
a stable environment while still allowing reversal when contingencies change.
