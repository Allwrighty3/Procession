# Roadmap

The detailed phase checklists include both completion blockers and future refinement ideas. The formal criteria for completing each section is listed at the bottom.

## Completed Phases

- [x] Phase 1: Core Entity System & Message Passing
- [x] Phase 2: Hierarchical Memory System
- [x] Phase 3: Local AI Integration with Ollama
- [x] Phase 4: Procedural Game Generator
- [x] Phase 5: Gameplay Systems & Polish
- [x] Phase 6: Entity Autonomy & Behavior Schema
- [x] Phase 7: World Simulation Clock & Scheduling
- [x] Phase 8: Game Session & Active Entity Ownership
- [x] Phase 9: Session-Aware Gameplay API
- [x] Phase 10: Player Entity & Location Context
- [x] Phase 11: Deterministic Command Parser
- [x] Phase 12: Basic Travel & Active Scope Preparation
- [x] Phase 13: First Playable Vertical Slice
- [x] Phase 14: Tiny Local CLI Loop

Detailed historical checklists live in [ROADMAP_ARCHIVE.md](ROADMAP_ARCHIVE.md).

---

## Current Focus

Procession now has a tiny local playable CLI loop. The next work should improve the playable experience only where it strengthens the underlying living-world simulation.

The project should not drift into being only a terminal text adventure. The CLI is a visibility layer for the Elixir/OTP simulation engine.

Current priorities:

- Clarify what different entity types are allowed to do.
- Keep simulation authority in Elixir.
- Keep AI output optional and validated.
- Improve starter-area playability enough to expose simulation behavior.
- Preserve the long-term path toward active scopes, cascading world generation, and selective spawning.

---

## Architecture Guardrails

These rules apply across future phases:

- Elixir remains authoritative over simulation state.
- Entities own their state, memory, and behavior metadata.
- `Procession.Game`, `Procession.GameSession`, `Procession.WorldClock`, `Procession.Command`, and `Procession.CLI` coordinate; they should not own entity behavior.
- Behavior metadata remains data, not executable code.
- AI-generated content is untrusted until validated.
- Ollama may generate expression or suggestions, but Elixir decides what actually changes.
- CLI and display formatting are player-facing adapters only.
- Inactive world content should remain blueprint or summary data until activated.
- Do not spawn the whole world as live OTP processes.
- Prefer visible, testable progress over abstract cleanup.

---

## Upcoming Phases

### Phase 15: Capability Boundaries & Playability Polish

Phase 15 clarifies what different entity types can do.

The goal is to prevent commands, ticking, travel, and dialogue from treating every entity as if it were an NPC-style actor. This protects the simulation model while making the CLI more understandable.

#### Entity capability rules

- [ ] Define the first simple capability rules for entity types.
  - NPCs are inspectable, talkable, askable, and tickable.
  - Players are inspectable and movable.
  - Locations are inspectable and may contain exits.
  - Factions are inspectable but not directly talkable or movable.
- [ ] Decide whether capability checks live in a small module or private helpers.
  - Example: `Procession.EntityCapabilities`
- [ ] Add helpers for common capability checks.
  - Example: `talkable?/1`
  - Example: `movable?/1`
  - Example: `location?/1`
  - Example: `tickable?/1`
- [ ] Keep capability checks separate from text parsing.
- [ ] Add tests for capability checks by entity type.
- [ ] Document that richer capability metadata may replace simple type checks later.

#### Gameplay error handling

- [ ] Prevent talking to non-talkable entities.
  - Example: locations and factions.
- [ ] Prevent travel to non-location entities.
- [ ] Prevent movement of non-movable entities if movement helpers become generic.
- [ ] Return predictable errors for unsupported capabilities.
  - Example: `{:error, :entity_not_talkable}`
  - Example: `{:error, :entity_not_movable}`
  - Example: `{:error, :entity_not_a_location}`
- [ ] Add tests for talking to a location.
- [ ] Add tests for talking to a faction.
- [ ] Add tests for trying to travel to an NPC.
- [ ] Add tests proving valid NPC dialogue still works.
- [ ] Add tests proving valid travel still works.

#### Tick behavior boundaries

- [ ] Decide which entity types should be ticked in the current simulation.
- [ ] First version should probably tick NPCs and skip player/location/faction autonomous behavior unless explicitly enabled.
- [ ] Keep behavior execution owned by `Entity.tick/1`.
- [ ] Avoid moving ticking rules into command parsing.
- [ ] Add tests proving non-tickable entities are not treated as autonomous actors if filtering is implemented.
- [ ] Keep failed behavior actions visible as structured data.

#### CLI and display polish

- [ ] Improve display output to prefer readable names over raw IDs where practical.
- [ ] Improve local entity output in `look`.
- [ ] Improve travel output after movement.
- [ ] Improve error messages for unsupported capabilities.
- [ ] Keep display formatting separate from simulation logic.
- [ ] Add tests for display formatting improvements.

#### Demo stability

- [ ] Add or update a short demo transcript test.
- [ ] Ensure the basic command loop still supports:
  - `look`
  - `look at Tobin`
  - `ask Tobin about road`
  - `talk to Tobin: Hello`
  - `wait`
  - `go to Briar Village`
  - `look`
  - `events for Mira`
- [ ] Keep the CLI deterministic by default.
- [ ] Ensure tests do not require Ollama.

#### Documentation

- [ ] Update `docs/USAGE.md` or demo docs with capability limits.
- [ ] Document that the CLI is a thin playability layer.
- [ ] Document that capability rules are intentionally simple for now.
- [ ] Document deferred richer capability metadata.

#### Deferred from Phase 15

- [ ] Defer inventory.
- [ ] Defer combat.
- [ ] Defer quests.
- [ ] Defer persistence.
- [ ] Defer AI command parsing.
- [ ] Defer large-world expansion.

---

### Phase 16: Starter Area Content Depth & Optional Ollama Dialogue

Phase 16 makes the current starter area more interesting while keeping the simulation safe.

The goal is to improve visible world reactivity and optionally allow Ollama-backed NPC dialogue without giving AI authority over game state.

#### Starter content depth

- [ ] Add richer deterministic starter memories.
- [ ] Add more useful ask-about topics.
- [ ] Add at least one additional visible NPC memory relationship.
- [ ] Add at least one visible world event that can be discovered after `wait`.
- [ ] Improve location descriptions to hint at current tensions.
- [ ] Ensure at least two NPCs have meaningful things to inspect or ask about.
- [ ] Keep demo content deterministic.
- [ ] Add tests for new starter memories and topics.

#### Visible world reactivity

- [ ] Add or refine behavior metadata so `wait` creates visible consequences.
- [ ] Ensure successful actions are visible through command/display output.
- [ ] Ensure failed actions remain visible for debugging.
- [ ] Ensure player-facing event inspection can reveal changes.
- [ ] Add tests proving `wait` changes later inspection or event output.

#### Optional Ollama dialogue

- [ ] Add an explicit way to request Ollama-backed NPC dialogue.
- [ ] Keep deterministic fake adapter as default for tests.
- [ ] Restrict AI dialogue to talkable NPCs.
- [ ] Include NPC state, traits, current location, player message, and relevant memories in the prompt.
- [ ] Return generated text only.
- [ ] Do not allow AI to directly mutate entity state.
- [ ] Do not allow AI to create behavior metadata in this phase.
- [ ] Do not use AI for command parsing.
- [ ] Add tests using the fake adapter.
- [ ] Add manual docs for trying Ollama locally.

#### CLI/demo integration

- [ ] Keep CLI deterministic by default.
- [ ] Consider a manual AI option only if it stays simple.
  - Example: `mix procession.play --ai`
  - Or defer this if it complicates the Mix task.
- [ ] Add IEx examples for AI-backed dialogue if CLI support is deferred.
- [ ] Document that Ollama is optional and not required for tests.

#### Deferred from Phase 16

- [ ] Defer AI autonomous planning.
- [ ] Defer AI-generated behavior metadata.
- [ ] Defer AI command interpretation.
- [ ] Defer memory mutation from AI output.
- [ ] Defer quest systems.
- [ ] Defer persistence.

---

### Phase 17: Rumor / Thread Prototype

Phase 17 introduces a small world-thread system.

The goal is to track emerging story threads without building a rigid quest system. Threads should help the player follow world activity while preserving the simulation-first design.

#### Thread model

- [ ] Define a simple thread data shape.
  - Example fields: `:id`, `:title`, `:state`, `:related_entities`, `:facts_discovered`, `:open_questions`.
- [ ] Keep threads as plain data first.
- [ ] Decide whether threads live in session state, entity memory, or a small separate module.
- [ ] Add a starter thread for the existing demo situation.
  - Example: the mine road, Tobin’s warning, Mira’s concern.
- [ ] Add tests for creating and inspecting thread data.

#### Thread discovery

- [ ] Allow player actions to reveal thread facts.
- [ ] Connect existing memories/events to thread discovery where simple.
- [ ] Add a session API for listing known threads.
  - Example: `Procession.GameSession.threads(session)`
- [ ] Add a session API for inspecting one thread.
- [ ] Add command support if useful.
  - Example: `threads`
  - Example: `thread mine road`
- [ ] Add tests for thread discovery through player interaction.

#### Thread progression

- [ ] Decide whether `wait` can advance a thread deterministically.
- [ ] Add one small deterministic thread progression.
- [ ] Keep progression inspectable as plain data.
- [ ] Do not create a full quest engine yet.
- [ ] Add tests proving a thread can progress.

#### Display and demo

- [ ] Add display formatting for known threads.
- [ ] Add a demo sequence showing thread discovery.
- [ ] Keep output readable but not overly polished.
- [ ] Document that threads are not full quests yet.

#### Deferred from Phase 17

- [ ] Defer quest rewards.
- [ ] Defer objectives/checklists unless they naturally emerge.
- [ ] Defer branching quest logic.
- [ ] Defer AI-authored thread progression.
- [ ] Defer persistence.

---

### Phase 18: Active Scope & Selective Simulation

Phase 18 returns to the long-term large-world architecture.

The goal is to formalize the difference between live active content and inactive blueprint/summary content. This prevents large worlds from becoming fully spawned GenServer forests. Yes, the forest is cool. No, we are not spawning every tree.

#### Active scope model

- [ ] Define a first active scope data shape.
  - Example fields: `:scope_id`, `:kind`, `:entity_ids`, `:location_ids`, `:faction_ids`, `:status`.
- [ ] Store active scope information in session state.
- [ ] Keep the first scope model simple and local.
- [ ] Add tests for active scope summary output.
- [ ] Document that active scope is runtime state, not the whole world.

#### Scope-aware ticking

- [ ] Update session ticking to tick only active-scope entities if not already doing so.
- [ ] Keep global world ticking available for debugging if useful.
- [ ] Ensure non-active entities are not ticked through the session.
- [ ] Add tests proving session tick only affects active scope.
- [ ] Add tests proving inactive entities remain untouched.
- [ ] Keep tick summaries inspectable.

#### Scope lifecycle

- [ ] Add helpers for activating a scope.
- [ ] Add helpers for deactivating a scope.
- [ ] First version may only support the starter scope.
- [ ] Do not implement full lazy generation yet.
- [ ] Add tests for activation/deactivation behavior.
- [ ] Ensure cleanup still stops live session-owned entities.

#### Blueprint separation

- [ ] Document the difference between:
  - generated blueprint data
  - active scope summaries
  - live entity processes
- [ ] Avoid storing all future content as live entities.
- [ ] Add small examples in `WORLD_GENERATION.md` if useful.

#### Deferred from Phase 18

- [ ] Defer region-scale generation.
- [ ] Defer save/load.
- [ ] Defer background simulation of inactive scopes.
- [ ] Defer full world maps.
- [ ] Defer multi-scope travel unless trivial.

---

### Phase 19: Cascading World Generation Foundation

Phase 19 begins the large-world generation pipeline.

The goal is not to generate everything at once. The goal is to generate broad summaries first, then expand details only when needed.

#### World hierarchy

- [ ] Define a high-level world hierarchy.
  - World overview.
  - Regions.
  - Local scopes.
  - Locations.
  - NPCs.
  - Factions.
- [ ] Keep hierarchy data as blueprints/summaries first.
- [ ] Do not spawn all generated content.
- [ ] Add validation for hierarchy references.
- [ ] Add tests for valid and invalid hierarchy data.

#### Region summaries

- [ ] Add deterministic region summary generation.
- [ ] Include region name, type, themes, tensions, and known factions.
- [ ] Keep summaries inert.
- [ ] Add tests for region summary shape.
- [ ] Add docs explaining inert region summaries.

#### Local scope expansion

- [ ] Add a function for expanding one region/local scope into a detailed blueprint.
- [ ] Validate expanded blueprint before spawning.
- [ ] Spawn only the selected active scope.
- [ ] Add tests proving expansion does not spawn unrelated regions.
- [ ] Add tests proving invalid expansion output is rejected.

#### Integration with session

- [ ] Allow a session to hold broader world summary data.
- [ ] Allow a session to activate one expanded local scope.
- [ ] Keep active scope ownership explicit.
- [ ] Add tests for activating generated scope data.

#### Deferred from Phase 19

- [ ] Defer AI-generated hierarchy if deterministic generation is not stable.
- [ ] Defer persistence.
- [ ] Defer background inactive-region simulation.
- [ ] Defer large-scale pathfinding.
- [ ] Defer economic/faction simulation.

---

### Phase 20: AI-Assisted Validated Expansion

Phase 20 uses local AI to propose larger world content.

The goal is to let Ollama assist generation without making it authoritative. AI proposes. Elixir validates. Invalid content gets rejected, repaired, or ignored. Revolutionary concept: do not let the robot drive the bus.

#### AI expansion boundary

- [ ] Add or extend an AI-assisted generation boundary for region/scope expansion.
- [ ] Keep prompts structured.
- [ ] Keep AI output as untrusted text or parsed data until validated.
- [ ] Reuse existing AI adapter pattern.
- [ ] Ensure tests use fake adapters.
- [ ] Add manual Ollama test instructions.

#### Structured output parsing

- [ ] Decide on a simple structured output format.
  - Example: JSON-like maps after parsing.
- [ ] Parse AI output into candidate blueprints.
- [ ] Validate candidate blueprints through existing validation boundaries.
- [ ] Return predictable errors for invalid AI output.
- [ ] Add tests for valid and invalid fake AI outputs.

#### Safe content activation

- [ ] Ensure AI-generated content is not spawned until validated.
- [ ] Spawn only selected validated scopes.
- [ ] Keep inactive generated summaries inert.
- [ ] Add tests proving invalid AI content is not spawned.
- [ ] Add tests proving valid AI-assisted content can become an active scope.

#### Diagnostics

- [ ] Add simple diagnostics for rejected AI output.
- [ ] Add prompt/response examples for local debugging.
- [ ] Consider Python tooling later for prompt evaluation or generation diagnostics.
- [ ] Do not add Python into the simulation runtime.

#### Deferred from Phase 20

- [ ] Defer AI autonomous planning.
- [ ] Defer direct AI state mutation.
- [ ] Defer AI command parsing.
- [ ] Defer full persistence.
- [ ] Defer background world simulation.

---

## Phase Completion Criteria

### Phase 15 is complete when:

- [ ] Basic entity capability rules exist.
- [ ] Gameplay APIs return predictable errors for unsupported capabilities.
- [ ] Non-talkable entities cannot be talked to.
- [ ] Non-location entities cannot be traveled to.
- [ ] Tick behavior boundaries are documented or enforced.
- [ ] CLI/display output is clearer without owning gameplay logic.
- [ ] Tests cover capability rules and common failure cases.
- [ ] The playable demo loop still works.
- [ ] Ollama, persistence, quests, combat, and large-world expansion remain deferred.

### Phase 16 is complete when:

- [ ] The starter area has richer deterministic memories or topics.
- [ ] At least one `wait` action creates a visible consequence.
- [ ] Player-facing inspection can reveal new world activity.
- [ ] Optional Ollama-backed NPC dialogue is available through an explicit safe path, or is clearly deferred with docs.
- [ ] AI dialogue returns text only and does not mutate game state directly.
- [ ] Tests do not require Ollama.
- [ ] Documentation explains deterministic play and optional AI dialogue.
- [ ] AI planning, AI command parsing, and AI-generated behavior mutation remain deferred.

### Phase 17 is complete when:

- [ ] A simple world-thread data model exists.
- [ ] At least one starter thread can be discovered.
- [ ] Player actions can reveal thread facts.
- [ ] Threads can be inspected through session APIs or commands.
- [ ] At least one deterministic thread progression exists if useful.
- [ ] Display output can show known threads.
- [ ] Tests cover thread discovery and inspection.
- [ ] Full quest systems, rewards, branching quests, and AI-authored progression remain deferred.

### Phase 18 is complete when:

- [ ] Active scope is represented as explicit session/runtime data.
- [ ] Session ticking can be limited to active-scope entities.
- [ ] Inactive content is not treated as live simulation.
- [ ] Scope activation/deactivation is tested at a simple level.
- [ ] Cleanup still handles live session-owned entities.
- [ ] Documentation explains active scope versus blueprint versus live process.
- [ ] Region-scale generation, persistence, and inactive background simulation remain deferred.

### Phase 19 is complete when:

- [ ] A cascading world hierarchy shape exists.
- [ ] Region summaries can be generated or represented as inert data.
- [ ] One local scope can be expanded from broader world data.
- [ ] Expanded scope data is validated before spawning.
- [ ] Only selected active scope content becomes live entity processes.
- [ ] Tests prove unrelated regions are not spawned.
- [ ] Documentation explains the broad-to-detailed generation pipeline.
- [ ] AI generation, persistence, and large-scale background simulation remain deferred unless explicitly started.

### Phase 20 is complete when:

- [ ] Local AI can propose region or scope expansion content through a controlled boundary.
- [ ] AI output is parsed into candidate data.
- [ ] Candidate data is validated before use.
- [ ] Invalid AI output returns predictable errors and is not spawned.
- [ ] Valid AI-assisted content can become an active scope.
- [ ] Tests use fake adapters and do not require Ollama.
- [ ] Manual Ollama instructions exist.
- [ ] AI remains non-authoritative over simulation state.