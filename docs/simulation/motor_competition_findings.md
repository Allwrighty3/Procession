# Motor competition findings

Validated with 100 deterministic seeds, 180 ticks, and reversal at tick 90.

```text
weighted_choice: obsolete=35.000 correction_delay=37.000 corrected=96 persistent=4 switches=59.500 conflict=0.000 entropy=0.977 left_fraction=0.592
motor_competition: obsolete=0.000 correction_delay=91.000 corrected=0 persistent=100 switches=0.000 conflict=26.414 entropy=0.000 left_fraction=0.000
fluctuating_competition: obsolete=3.000 correction_delay=91.000 corrected=41 persistent=59 switches=0.000 conflict=21.837 entropy=0.781 left_fraction=0.135
```

## Interpretation

The deterministic motor channels began with equal state and received equal activation. Their mutual competition preserved symmetry, so net pressure never exceeded embodied resistance. Remaining in place emerged without a `:remain` probability, but the system produced no behavioral distribution.

Small seeded fluctuations broke symmetry and produced population divergence. However, persistent channel activation converted the first imbalance into long-lived commitment. Within-entity entropy increased, but action switching remained effectively absent and most entities did not reorganize after reversal.

The weighted-choice control remained much more behaviorally flexible and corrected in 96 of 100 histories. This does not prove that explicit weighted selection is the right final mechanism. It shows that persistent excitation plus inhibition is insufficient by itself.

A useful next experiment should add ordinary consequences of motor activation rather than an explicit chooser: expenditure, refractory suppression, unresolved activation after expected displacement fails, and environmental resistance. Those dynamics may prevent a winning channel from permanently monopolizing output while keeping the observed behavioral distribution external to the entity.
