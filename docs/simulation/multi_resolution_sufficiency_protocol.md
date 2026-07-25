# Multi-Resolution Sufficiency Protocol

This protocol defines the current falsification standard for Procession's three-layer world architecture. It is intended to be exhaustive according to the project's current understanding, not a permanent claim that no additional failure classes exist.

## Layers

- **Physical:** matter, location, access, capacity, bodily state, conserved stocks, resource flow, and material consequences.
- **Mental:** activation, relational memory, salience, inhibition, habituation, adaptation, and motor influence.
- **Social/institutional:** trust, obligations, distribution, authority-like persistence, and effects that outlive one interaction.

The layers may share relational mechanisms, but they are not required to use one identical data structure or update law.

## Sufficiency claims under test

1. **Causal branching:** distinct histories can preserve distinct futures.
2. **Causal transmission:** effects can cross mental, physical, household, social, and settlement boundaries.
3. **Locality:** an event does not directly mutate unrelated state.
4. **Cross-domain composition:** novel combinations interact without a named scenario implementation.
5. **Ablation sensitivity:** removing a proposed mechanism removes capabilities it is meant to explain.
6. **Refinement consistency:** a coarse state can produce multiple detailed states consistent with its commitments.
7. **Compression continuity:** fine state can be summarized without erasing future-relevant pressures, history, or conserved stocks.
8. **Round-trip stability:** fine -> coarse -> fine continuation remains within a causal envelope of a continuously fine control.
9. **Scale-direction consistency:** the same intervention has compatible directional effects across resolutions.
10. **Computational viability:** active influence and summary size remain bounded as history and simultaneous input grow.

## Current automated coverage

`MultiResolutionSufficiencyTest` covers:

- mental history divergence, habituation, extreme-event persistence, and salience ablation;
- physical injury, mobility, labor, access, resource, and locality contracts;
- social trust, support, institutional distribution, and persistent obligation contracts;
- cross-layer injury and combined-intervention propagation;
- fine/coarse/refined round trips and non-unique causal reconstruction;
- summary compression and bounded active-mass checks.

The complete repository suite currently passes with **1,044 tests and 0 failures** under strict compilation with warnings treated as errors.

## Discovered coarse-state requirement

The first round-trip implementation retained pressure values but discarded the household and settlement food stocks that generated those pressures. It could therefore reproduce a label such as `food_pressure` while evolving from a physically different state.

The reference summary now retains:

- household food stock;
- settlement food stock;
- reserve stock;
- population and household count;
- aggregate labor capacity;
- bodily, social, and institutional pressures;
- sparse causal flags for histories whose future effects cannot be reconstructed from current aggregates alone.

This is a general rule: a coarse summary must retain conserved or slowly changing quantities that constrain future transitions. Pressures and trends alone are not sufficient.

## Interpretation boundary

The test harness uses the production developmental mental plane. Its physical and social layers are deterministic reference models used to define causal contracts. Passing these tests proves that the candidate mechanisms can compose under the current model; it does not prove that Procession's final physical and institutional implementations are complete.

When production physical or institutional planes are added, they must replace the corresponding reference portions of the harness while preserving these contracts.

## Failure interpretation

A failure is evidence of one of four things:

- a missing primitive;
- an incorrect cross-layer coupling;
- an insufficient coarse summary;
- or an unstable/overly expensive implementation.

Tests should not be weakened merely to preserve a preferred architecture. Thresholds may be recalibrated only when supported by measured variance, removal of a saturation artifact, or a better-defined causal envelope.
