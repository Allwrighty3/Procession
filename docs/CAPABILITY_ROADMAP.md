# Procession Capability Roadmap

This roadmap describes what Procession can do, what has only been demonstrated experimentally,
and what must become player-visible before the project advances to broader world generation.
Historical numbered phases remain in `ROADMAP.md` and `ROADMAP_ARCHIVE.md`.

## Completion rule

A capability is complete only when it has:

1. an authoritative production owner;
2. strict tests for its invariants;
3. a reproducible experiment or playable trace;
4. no hidden correct action, destination, narrative role, or semantic conclusion;
5. a clear scaling and persistence boundary.

## Production foundations complete

- OTP entity supervision, message passing, memory, sessions, deterministic commands, and CLI play.
- Validated AI dialogue boundaries with non-authoritative model output.
- Authoritative physical world state and local physical perception.
- Developmental sensory, relational, salience, imprint, and opaque motor learning.
- Observation-derived directed social history without named social conclusions.
- Live, coarse, and inert region resolutions with bounded identity and mind retention.
- Automatic grounded region activation and deactivation policy.
- Dormant anchored identity continuity, migration, transit, and open-ended travel episodes.
- Lifecycle-owned dormant mind compare-and-swap and compensated travel persistence.
- Fair bounded dormant cognition scheduled independently from world time.
- Conserved low-level material gathering, transformation, consumption, and contact transfer.

## Experimentally proven but not yet fully playable

- Three-region population redistribution without destination metadata.
- Population changes altering later regional pressure and bodily state.
- Archived developmental minds producing material and migration consequences.
- Scheduler budget changing migration outcomes and CPU cost.
- Nearby actor observation changing directed relational history.
- Contact-grounded held-resource transfer.

These systems are production-grade enough to reuse, but most are still reached through metrics and
scenario APIs rather than the ordinary player session.

## Current canonical scenario: Living Briar

`Procession.Simulation.LivingBriar` is the canonical integration scenario shared by tests, metrics,
and IEx observation. New simulation work should extend this scenario or its production owners rather
than creating another private world fixture.

Run it from IEx:

```elixir
Procession.Demo.watch_living_briar()
Procession.Demo.watch_living_briar(ticks: 96, budget: 3, cadence: 1, seed: 41)
```

The trace exposes only observable causal evidence:

- serviced and deferred cognition;
- motor-derived primitive attempts;
- physical consequences;
- material amounts;
- migration;
- regional population and pressure;
- mind persistence success.

## Milestone A: first truly living playable slice

The starter-area session and Living Briar simulation must become one world.

Completion criteria:

- the player enters and observes the same authoritative regions used by simulation tests;
- ordinary `wait` advances physical, social, material, dormant, and regional systems;
- NPC dialogue reads current authoritative experience and relationships;
- residents gather, transform, consume, transfer, and migrate without scenario policy choosing for them;
- player intervention changes later behavior and regional conditions;
- an observer trace explains consequences without exposing hidden mental answers.

## Milestone B: self-sustaining settlement

Completion criteria:

- context-sensitive learned material behavior;
- persistent actions that take time and can be interrupted;
- grounded signal emission and reception;
- visible approach, withdrawal, following, and dependency;
- rest, injury, prolonged scarcity, and death;
- dependent development and caregiving;
- no hidden settlement planner.

## Milestone C: selectively simulated regional world

Completion criteria:

- multiple settlements and routes operating across live, coarse, and inert resolutions;
- durable identity, archive, transit, region, and world-clock persistence;
- restart recovery and transition-journal tests;
- regional change continuing without player presence;
- bounded cost as dormant population grows.

## Milestone D: cascading generated world

Completion criteria:

- generated content begins as validated blueprint or summary data;
- local causal pressure triggers deeper generation;
- generated detail inherits existing history and regional commitments;
- only relevant content becomes live OTP state;
- world expansion is iterative rather than one flat generation pass.

## Immediate sequence

1. Make Living Briar observable through the standard demo boundary.
2. Connect the canonical scenario to the normal `GameSession` and `wait` path.
3. Prove context-sensitive material learning with paired controls.
4. Add persistent physical actions for gathering, transformation, rest, and transfer.
5. Add grounded signaling and reception.
6. Convert social history into visible approach, avoidance, and following.
7. Add bodily persistence, death, dependent development, and caregiving.
8. Deepen material types, tools, shelter, storage, degradation, and regional ecology.
9. Add durable persistence and crash recovery.
10. Broaden procedural generation only after Milestones A-C are satisfied.

## Deliberate non-goals for the current milestone

- spawning the full generated world;
- replacing Elixir simulation authority with an AI model;
- adding named jobs, friendships, goals, economies, or migration plans as primitives;
- optimizing dormant cognition before measuring a real integrated playable workload;
- graphical-client work before the living simulation is visible and stable through CLI/IEx.
