# Stable contingency factorial findings

## Question

Does relaxing field plasticity improve reversal by making useful pathways too easy to forget, and does refractory motor suppression carry a retention cost when the environment remains stable?

## Corrected control

An initial spatial version was invalid as a stable-retention control because repeated left movement eventually reached a boundary, after which left output stopped producing a useful consequence.

The corrected experiment keeps the action-consequence mapping stable for the full run:

- left output always produces a positive local consequence
- right output always produces a negative local consequence
- inactivity produces no consequence
- the entity receives no correct-action label

The experiment crosses:

- embodied fatigue versus channel-specific refractory suppression
- current, moderate, and flexible field-plasticity profiles
- 100 deterministic seeds over 220 ticks

## Results

| Motor dynamics | Plasticity | Acquired | Late useful | Late harmful | Late inactive | Longest useful streak |
|---|---|---:|---:|---:|---:|---:|
| Embodied | Current | 97/100 | 1.000 | 0.000 | 0.000 | 162.5 |
| Embodied | Moderate | 97/100 | 1.000 | 0.000 | 0.000 | 159.5 |
| Embodied | Flexible | 97/100 | 1.000 | 0.000 | 0.000 | 156.5 |
| Refractory | Current | 99/100 | 0.027 | 0.009 | 0.964 | 1.0 |
| Refractory | Moderate | 99/100 | 0.018 | 0.009 | 0.968 | 1.0 |
| Refractory | Flexible | 99/100 | 0.018 | 0.009 | 0.964 | 1.0 |

## Interpretation

Within embodied motor dynamics, all three plasticity profiles retained the useful behavior perfectly during the late observation window. The flexible profile shortened the longest uninterrupted useful streak slightly, but it did not increase harmful drift or inactivity.

Therefore the measured four-point reversal gain from relaxed plasticity did not carry a detectable stable-retention penalty in this control.

Refractory suppression produced the opposite pattern. It acquired the useful pathway slightly more often and earlier, but nearly eliminated its continued expression. About 96% of late behavior became inactive, and the median useful streak was one tick.

The field still registered a slight preference for the useful route, but the motor substrate prevented that organization from being expressed continuously.

## Architectural consequence

Refractoriness should not be promoted as a global motor rule in its current form. It improves reversal by interrupting dominance, but it also interrupts still-valid behavior far too aggressively.

The next experiment should make refractory pressure conditional on unresolved or repeatedly unsuccessful output rather than on successful sustained output itself. That preserves a mechanism for escaping obsolete behavior without punishing stable effective behavior simply for continuing.

The current moderate field profile remains a plausible plasticity candidate, but the stable control gives no evidence that the flexible profile is too forgetful over this time horizon. Longer delayed-retention tests are still needed before changing global defaults.
