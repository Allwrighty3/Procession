# Directed Recursive Developmental Field Findings

## Change

The developmental field now:

- stores edges as directed `{source, target}` relationships;
- reactivates generated nodes before plasticity;
- permits generated nodes to strengthen edges;
- permits generated nodes to support later generated nodes;
- strengthens residual earlier activity toward newly rising activity;
- allows reciprocal edges to form when repeated coactivation supplies evidence in both directions.

The previous canonical undirected edge representation was a regression from the intended architecture.

## Validation

Compilation with warnings as errors, the complete test suite, all prior simulation metrics, the developmental-origin factorial, and the extended temporal probe passed in CI.

New tests verify:

- temporal order can produce `A -> B` without requiring `B -> A`;
- generated nodes participate in later plasticity;
- generated-to-generated edges can form;
- generated nodes can become members of later generated support.

## Extended temporal probe

At 720 ticks, the baseline produced 19 generated nodes and 3,892 directed edges. Reversing or block-reversing history changed node count, support, edge set, and edge weights.

At 2,880 ticks, the baseline produced 40 generated nodes and 6,968 directed edges. Generated-to-generated directed relationships reached 1,560 in the baseline-scale graph and varied across order controls.

At 11,520 ticks, the baseline produced 52 generated nodes and 9,116 total directed edges. Generated-to-generated relationships reached 2,652, exactly `52 * 51`, meaning every generated node had an edge to every other generated node.

This shows that higher-order relations are now reachable, but unrestricted reciprocal coactivation eventually saturates the generated-node subgraph.

## Interpretation

The earlier failure was substantially caused by only allowing freshly encoded micro-nodes to participate in plasticity. Generated nodes were terminal summaries and could not become prior understanding for later learning.

After correcting that oversight:

- generated structure participates in future learning;
- directed temporal relationships form;
- order sensitivity increases strongly at shorter and medium horizons;
- higher-order generated structure becomes reachable.

However, long-run reciprocal coactivation makes the graph increasingly symmetric and complete. The current field therefore has the required primitive capability but lacks selective pressure that preserves meaningful direction and locality.

The next question is not whether to restore undirected edges. It is how activity competition, local propagation, inhibition, or plasticity normalization can prevent every active generated region from strengthening toward every other active generated region.
