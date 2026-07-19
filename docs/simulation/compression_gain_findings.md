# Compression gain findings

Generated nodes now require positive amortized description-length gain before consolidation.

For a candidate support observed `r` times:

```text
direct cost = recurrence × support size × direct unit cost
compressed cost = node definition cost + support-link costs + recurrence × node-use cost
compression gain = direct cost - compressed cost
```

Default costs:

- direct unit cost: 1.0
- generated-node definition: 5.0
- each support link: 1.0
- each compressed use: 1.0
- minimum gain: 2.0

This makes small wrapper combinations expensive. A two-member candidate does not become cheaper until it has recurred substantially more often than a broad support whose definition can replace many active elements per use.

## Extended results

Before compression gain, explanatory substitution produced 133 generated nodes at 11,520 ticks and consolidated roughly 60% of eligible recurring signatures in the population experiment.

With compression gain:

```text
720 ticks:    16 baseline nodes
2,880 ticks:  25 baseline nodes
11,520 ticks: 61 baseline nodes
```

Population results at 2,880 ticks:

```text
clones:        25 nodes, 41.7% eligible coverage
salted:        16..28 nodes, 43.1% eligible coverage
varied:        14..26 nodes, 44.3% eligible coverage
salted varied: 13..34 nodes, 40.7% eligible coverage
```

Compression gain therefore reduced the long-run baseline from 133 to 61 nodes and eligible-signature consolidation from about 60% to about 42%.

The field still grows over long development, so this is not a final memory economy. The remaining growth may represent genuinely amortized higher-order structures, but future diagnostics should total stored model cost and realized use savings across the whole field rather than judging each node only at formation time.
