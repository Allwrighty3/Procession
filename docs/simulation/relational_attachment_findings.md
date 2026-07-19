# Relational Attachment Findings

## Purpose

This experiment reconnects caregiver development to the proposed relational/geometric mental-state model.

The child still has physical capacity and temperature because those are body constraints. Caregiver significance, motor tendency, eligibility, and memory are represented in a relational field:

- node activity represents currently active patterns;
- weighted edges represent permeability between patterns;
- eligibility represents temporary edge activation;
- regulation strengthens eligible edges;
- motor output is read from competing motor-node activity;
- psychological descriptions are derived by an external observer.

There is no attachment score, follow-parent force, separation penalty, resource direction, or symbolic memory record.

## Conditions

Twenty seeds ran for 1,800 ticks under four conditions:

1. responsive regulated caregiver;
2. passive regulated caregiver;
3. responsive visible but unregulated caregiver;
4. no parent.

## Results

```text
responsive_regulated: survived=0 lifetime=407.000 memory_edges=3.000 memory_mass=0.104 reunions=1.500 interventions=229.500 approach=0.170
passive_regulated: survived=0 lifetime=334.500 memory_edges=3.000 memory_mass=0.109 reunions=1.000 interventions=0.000 approach=0.236
responsive_unregulated: survived=0 lifetime=96.000 memory_edges=0.000 memory_mass=0.000 reunions=0.000 interventions=96.000 approach=0.000
no_parent: survived=0 lifetime=96.000 memory_edges=0.000 memory_mass=0.000 reunions=0.000 interventions=0.000 approach=0.000
```

## Interpretation

This is the first experiment in this sequence where caregiver regulation changed mental geometry rather than a direct associative table.

Regulated caregiver conditions produced a median of three strengthened cue-to-motor edges. Unregulated and no-parent controls produced none. This means visible caregiver cues and responsive intervention were not sufficient by themselves; bodily regulation was required for recent relational activity to consolidate into persistent permeability.

Responsive regulated children also produced a median of 1.5 reunions. That is still weak, but it demonstrates that child movement could close caregiver distance without a direct follow force.

The passive regulated condition produced slightly greater approach fraction than the responsive condition. Responsive rescue may still be reducing the child's opportunities to complete approach sequences independently.

## Limitations

This is a minimal geometric substrate, not the final model.

- Node kinds are still authored: caregiver cue bands, disturbance, regulation, and motor channels.
- Physical capacity and temperature remain scalar body variables.
- The field topology begins with candidate cue-to-motor edges rather than growing arbitrary structure.
- All children still die before 1,800 ticks.
- Disturbance saturates at 1.0 by the end of failed runs, making the terminal mental-state metric uninformative.
- Median memory contains only three edges and does not yet establish robust attachment or independent survival.
- Eligibility is cleared at regulation, so terminal eligibility mass is expected to be zero and should be supplemented with event counts.

## Strongest defensible conclusion

Repeated caregiver regulation can alter a child's relational field geometry and produce weak caregiver-directed behavior without an authored follow-parent force.

This is evidence for learned relational structure, not yet evidence for robust attachment.

## Next measurements

The next version should add observer-only counters and event windows for:

- eligibility traces created, expired, and reinforced;
- edge-strength trajectories by developmental phase;
- child-closed versus parent-closed distance;
- field activity before and after reunion;
- cue-node activation after permanent departure;
- motor conflict and search behavior after caregiver loss;
- whether learned geometry persists when the caregiver route changes.
