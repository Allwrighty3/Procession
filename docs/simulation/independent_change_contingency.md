# Independent-change contingency validation

This experiment compares reactive, outcome-only adaptive, and locally adaptive behavior under reliable and noisy movement, with and without environmental intake changes that occur independently of the entity's actions.

The world stores current state only. The entity retains event-specific, decaying traces for emitted action and sensed displacement. The experiment runner keeps counterfactual diagnostics only to classify whether an attribution was accurate or mistaken; those diagnostics are never available to the entity.

Run the repeatable population metrics with:

```bash
mix procession.metrics.independent_change --samples 100 --ticks 220
```

The validated 100-seed run showed:

- outcome-only adaptation misattributed 40.2% to 57.4% of learned positive outcomes, depending on environmental and motor noise;
- local trace overlap reduced misattribution to 15.9% to 28.1%, but did not eliminate it;
- independent environmental changes increased misattribution for both adaptive variants;
- noisy movement increased misattribution and generally reduced survival;
- local adaptation improved survival over reactive behavior in the independently changing environment, from 65 to 81 survivors under reliable movement and from 58 to 61 under noisy movement;
- outcome-only adaptation sometimes survived more often, but did so while forming substantially more mistaken associations.

The useful conclusion is not that local traces reveal true causality. They bias learning toward locally supported regularities while leaving room for coincidence, superstition, correction, and divergent histories.
