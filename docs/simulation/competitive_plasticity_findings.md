# Competitive Plasticity Findings

## Change

Developmental-field plasticity now operates under a finite local budget per source node.

- Every edge remains directed.
- Simultaneous activity supplies reciprocal evidence only when each source independently selects the other as a strong competitor.
- Residual earlier activity supplies stronger evidence toward newly rising targets.
- Each source reinforces at most a configured number of targets per tick.
- The source budget is divided among selected targets rather than copied to every active pair.
- Existing relationships are not classified as beneficial or harmful and are not deleted by this mechanism.

Default experiment settings use a fanout of six and a per-source plasticity budget of 0.08. Temporal evidence receives twice the candidate weight of simultaneous coactivation.

## Extended probe

The 11,520-tick probe no longer converged to a complete generated-node graph.

Previous unrestricted result:

- 52 generated nodes
- 2,652 generated-to-generated directed relations
- 2,652 is the complete directed graph: `52 * 51`

Competitive result variants at 11,520 ticks:

- reversed: 52 nodes, 1,513 generated relations
- rotated: 52 nodes, 1,459 generated relations
- block-reversed: 47 nodes, 1,264 generated relations

Meaningful order sensitivity also remained instead of disappearing into identical edge sets:

- reversed edge-set similarity: 0.793
- rotated edge-set similarity: 0.835
- block-reversed edge-set similarity: 0.789

The corresponding edge-weight similarities were 0.716, 0.953, and 0.721.

## Interpretation

The finite budget preserved recursive higher-order learning while preventing every active source from strengthening every available target on every tick. The graph still grows substantially, which is expected for a long repetitive stream, but it remains selective enough for different temporal histories to retain different topology.

This is not evidence that every retained relationship is useful or beneficial. It is evidence that relationships now compete for plasticity based on local activity and timing rather than being granted reinforcement automatically.

The rotated history remains much more similar in edge weights than reversed histories. That is reasonable because rotation preserves most local order while changing the phase boundary. Reversal and within-block reversal alter local direction more strongly.

## Remaining limitations

- Candidate selection uses activity strength and temporal priority but no propagation locality yet.
- Deterministic target ordering breaks exact ties, which may repeatedly favor low node IDs under perfectly equal evidence.
- Support edges inserted at node creation are outside the per-tick plasticity budget.
- The graph can still become dense over very long histories because different competitors may win on different ticks.
- The staged three-pattern probe still produced only two generated nodes and one generated relation, so the current consolidation mechanism remains coarse for deliberately minimal sequences.
