# Compression computational cost findings

A five-sample, 2,880-tick benchmark compared:

- gain-gated explanatory compression,
- explanatory compression with a permissive gain threshold,
- explanation disabled.

The benchmark records median wall time, BEAM reductions, retained state words, generated nodes, edge count, and average learning-field size.

```text
gain_vs_permissive runtime_ratio=0.929 reduction_ratio=0.926 state_ratio=0.970

gain_gated:
  median_us=1239548
  median_reductions=104799805
  generated=25
  edges=1556
  state_words=67692
  avg_learning_field=1.539

permissive_gain:
  median_us=1334662
  median_reductions=113199261
  generated=43
  edges=1645
  state_words=69776
  avg_learning_field=1.537

explanation_disabled:
  median_us=10479662
  median_reductions=866740332
  generated=41
  edges=5288
  state_words=167018
  avg_learning_field=56.984
```

## Interpretation

The gain calculation does not create a net computational penalty in this workload. Gain-gated compression is about 7% faster, uses about 7% fewer BEAM reductions, and retains about 3% less state than permissive compression. The reduced number of generated nodes more than repays the constant-time gain arithmetic.

Disabling explanatory compression is much worse: runtime is roughly 8.5 times higher, reductions roughly 8.3 times higher, and retained state roughly 2.5 times larger. The average learning field grows from about 1.54 nodes to nearly 57 nodes, causing edge competition and graph maintenance to dominate execution.

This is a workload-specific benchmark rather than a universal proof. It should remain in CI so regressions become visible as the field and developmental streams evolve.
