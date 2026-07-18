# Embodied Motor Competition Findings

## Question

Can a behavioral distribution and reversal response emerge from persistent motor
channels when sustained dominance has ordinary embodied costs, rather than from a
final weighted action selector?

## Mechanism

The embodied competition control extends persistent left and right motor channels
with:

- fatigue accumulated by the active channel
- fatigue recovery while a channel is inactive
- fatigue suppressing later activation in the same channel
- tiny seeded fluctuations entering motor pressure before embodiment
- failed movement against a world boundary disturbing the active cognitive route

There is no exploration reward, forced switch, or `:remain` action. Remaining in
place means net pressure did not overcome the body threshold.

## Validated 100-sample results

Each run lasted 180 ticks. The useful direction reversed at tick 90.

| Mode | Obsolete actions | Median correction delay | Corrected | Persistent | Median switches | Entropy |
|---|---:|---:|---:|---:|---:|---:|
| Weighted choice | 35 | 37 | 96 | 4 | 59.5 | 0.977 |
| Deterministic competition | 0 | 91 | 0 | 100 | 0 | 0.000 |
| Fluctuating competition | 3 | 91 | 41 | 59 | 0 | 0.781 |
| Embodied competition | 2 | 90.5 | 50 | 50 | 0 | 0.514 |

The embodied control also produced:

- median accumulated fatigue cost: 1.179
- median failed-motion feedback events: 4
- population left-action fraction: 0.056

## Interpretation

Embodied cost partially loosened the early commitment created by fluctuating motor
competition. Correction improved from 41 of 100 histories to 50 of 100, and
failed displacement generated actual contradiction through the active pathway.

However, the improvement did not come from frequent direct switching. Median
switches remained zero. Fatigue mostly reduced the dominant channel below the
movement threshold, producing stationary recovery periods rather than allowing the
opposing channel to take control.

This is still a useful causal result:

```text
sustained dominance
-> fatigue
-> reduced output
-> pauses and occasional pathway correction
```

But the current mechanism does not yet produce:

```text
sustained dominance
-> fatigue
-> competing channel becomes active
-> alternate behavior receives consequences
-> flexible reversal
```

The missing connection is not an exploration policy. It is a way for unresolved or
suppressed motor activation to remain available to competing channels instead of
simply disappearing below the movement threshold.

## Reproduction

```bash
mix procession.metrics.motor_competition \
  --samples 100 \
  --ticks 180 \
  --reversal-tick 90
```
