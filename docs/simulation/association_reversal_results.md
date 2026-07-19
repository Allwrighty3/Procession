# Association Reversal Metrics

Run with:

```bash
mix procession.metrics.association_reversal --samples 100 --ticks 180 --reversal-tick 90
```

The environment favored leftward movement before tick 90 and rightward movement afterward. The entity received no reversal flag or correct-action label. Evaluation labels were calculated only by the experiment runner.

## Results

| Variant | Misattribution rate | Obsolete actions | Correction delay | Corrected | Persistent |
|---|---:|---:|---:|---:|---:|
| Outcome adaptive | 75.0% | 88 | 91 ticks | 4/100 | 96/100 |
| Local adaptive | 20.0% | 85 | 91 ticks | 2/100 | 98/100 |

## Interpretation

Local action and displacement overlap substantially reduced mistaken reinforcement, but it did not make established pathways easy to revise. Both variants continued selecting the formerly useful action through nearly the entire post-reversal period.

The result separates attribution quality from revision capacity. The current substrate improves attribution quality but has weak revision capacity. Future experiments should test whether ordinary field dynamics can produce revision through contradictory activation, residue decay, competing contextual activation, or renewed exploration without adding explicit beliefs, confidence scores, reversal detectors, or correct-action tables.
