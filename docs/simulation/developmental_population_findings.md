# Developmental population findings

The population experiment separates three questions:

1. whether exact clones remain deterministic,
2. whether small representational or experiential differences produce individual development,
3. whether generated memory simply catalogs every recurring active-field signature.

## Configuration

- 8 entities per population
- 2,880 ticks
- shared deterministic environment for clone and salted groups
- small phase and motor-history variation for varied-history groups
- optional entity-specific encoding salt

## Results

```text
clones: nodes=41.000 range=41..41 eligible_coverage=0.177 distinct_coverage=0.039 support=1.000 edges=1.000 profile=1.000
salted: nodes=37.875 range=35..44 eligible_coverage=0.178 distinct_coverage=0.040 profile=0.899
varied_history: nodes=40.875 range=36..45 eligible_coverage=0.195 distinct_coverage=0.040 support=0.944 edges=0.834 profile=0.928
salted_varied: nodes=40.875 range=31..47 eligible_coverage=0.180 distinct_coverage=0.040 profile=0.852
```

## Interpretation

Exact clones remain exact clones. This is the expected deterministic control.

Entity-specific encoding alone produces a 35–44 node range and lowers structural-profile similarity to 0.899. Small history variation produces a 36–45 range, support similarity of 0.944, and edge similarity of 0.834. Combining both produces the widest range, 31–47, and the lowest profile similarity, 0.852.

Therefore the previously repeated count was not a universal attractor. It came from identically initialized fields receiving highly similar deterministic histories.

The memory-catalog concern is not supported by this run. Generated nodes represented only about 17.7–19.5% of signatures that recurred at least four times, and about 4% of all observed signatures. The field is selective, although this metric does not yet prove that the selected signatures are the most causally or developmentally important ones.

The next consolidation question is not whether every combination is stored. It is why these particular recurring structures win consolidation and whether selection remains stable under richer, less repetitive environments.
