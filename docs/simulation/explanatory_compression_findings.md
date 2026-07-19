# Explanatory compression findings

Generated nodes now greedily claim familiar support for the learning path while raw activity remains intact for simulation behavior and observation.

## Mechanism

After generated-node reactivation:

1. active generated nodes are scored by support coverage and stability,
2. stronger candidates greedily claim currently active support members,
3. claimed support is attenuated only in the learning activity map,
4. plasticity, recurrence, and consolidation use generated nodes plus unexplained residual activity,
5. raw activity remains unchanged in field state.

A focused test confirms that familiar support remains active in the raw field while the learning field becomes smaller.

## CI result

Compilation, the complete test suite, existing metrics, temporal probes, and population metrics passed.

## Population result at 2,880 ticks

```text
clones: nodes=43 range=43..43 eligible_coverage=0.623 distinct_coverage=0.287
salted: nodes=17..48 eligible_coverage=0.605 distinct_coverage=0.226
varied_history: nodes=37..47 eligible_coverage=0.621 distinct_coverage=0.289
salted_varied: nodes=13..52 eligible_coverage=0.602 distinct_coverage=0.247
```

The mechanism increased consolidation coverage from roughly 18% to roughly 60% of recurrence-eligible signatures.

## Extended result

```text
720 ticks: baseline 21 nodes
2,880 ticks: baseline 43 nodes
11,520 ticks: baseline 133 nodes
```

This is a failure of global compression despite successful local explanation.

The current greedy mechanism removes familiar support from the learning signature but leaves the active generated node. Different generated-node-plus-residual combinations then become new exact signatures. Those signatures consolidate, adding more generated nodes, which creates still more possible compressed combinations.

Therefore the implementation currently performs substitution without measuring whether a new node reduces total description length. It can turn flat snapshot proliferation into hierarchical combination proliferation.

## Conclusion

Generated nodes can now explain familiar support, but node creation still lacks a compression-gain requirement. A candidate should not consolidate merely because its compressed signature recurs and is coherent. It must reduce representation cost compared with existing generated nodes plus residuals.
