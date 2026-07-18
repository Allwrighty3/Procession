# Motor Redistribution Findings

## Question

Can suppressed or failed motor output remain local and redistribute into a competing channel, allowing behavioral redirection to emerge without an explicit exploration policy?

## Mechanism

The `:redistributed_competition` control extends embodied motor competition:

- fatigue-suppressed pressure is partially transferred into the opposing motor channel;
- movement that reaches a world boundary leaves a one-tick unresolved motor residue;
- that unresolved residue is transferred into the opposing channel on the next tick;
- no action probability, exploration bonus, forced switch, or correct-direction signal is added.

The experiment runner measures transferred activation, but the entity has no access to that diagnostic or to world causality.

## Validation

GitHub Actions run `29650549531` passed:

- compilation with warnings as errors;
- the complete ExUnit suite;
- 100-sample causal-attribution metrics;
- 100-sample association-reversal metrics;
- 100-sample motor-competition metrics;
- artifact upload.

## 100-sample reversal results

| Mode | Corrected | Persistent | Median correction delay | Median switches | Entropy | Redistributed activation |
|---|---:|---:|---:|---:|---:|---:|
| weighted choice | 96 | 4 | 37.0 | 59.5 | 0.977 | 0.000 |
| fluctuating competition | 41 | 59 | 91.0 | 0.0 | 0.781 | 0.000 |
| embodied competition | 50 | 50 | 90.5 | 0.0 | 0.514 | 0.000 |
| redistributed competition | 39 | 61 | 91.0 | 0.0 | 0.374 | 0.421 |

The redistributed control also had median fatigue cost `0.788`, median failed-motion feedback `2`, and only `3.6%` of all actions were leftward.

## Interpretation

The mechanism successfully conserved and transferred some local activation, but it did not create flexible redirection.

Transferred pressure entered a competing channel that was already simultaneously active. This increased shared motor pressure and conflict rather than creating a temporary window in which the alternative channel could dominate. Fatigue and redistribution therefore produced more inactivity and lower behavioral entropy.

Correction fell from `50/100` in embodied competition to `39/100` in redistributed competition. Direct directional switches remained at a median of zero.

The negative result distinguishes two ideas that initially looked equivalent:

```text
suppressed output -> competing activation
```

is not automatically the same as:

```text
suppressed output -> alternative behavior becomes executable
```

The latter also requires temporal separation, asymmetric recovery, or another causal process that prevents transferred activation from merely joining the existing conflict.

## Architectural conclusion

Do not promote direct cross-channel redistribution as the current motor architecture.

A stronger next candidate is temporary refractory separation:

```text
sustained channel output
-> channel-specific refractory period
-> its pressure cannot immediately re-enter competition
-> unresolved activation remains available elsewhere
-> another channel may transiently dominate
```

That differs from forced switching because no alternative is selected. The active pathway simply becomes temporarily unavailable as a physical consequence of sustained use.
