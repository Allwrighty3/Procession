# Roadmap

The detailed historical phase checklists live in [ROADMAP_ARCHIVE.md](ROADMAP_ARCHIVE.md). This file tracks completed milestones, current priorities, upcoming phases, and phase completion criteria.

---

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

## Upcoming Phases

### Current Focus

- [ ] Phase 15: Capability Boundaries & Playability Polish

### Near-Term

- [ ] Phase 16: AI-Backed NPC Dialogue Through Safe Boundaries
- [ ] Phase 17: Starter Area Content Depth & World Reactivity
- [ ] Phase 18: Rumor / Thread Prototype

### Larger Simulation Direction

- [ ] Phase 19: Active Scope & Selective Simulation
- [ ] Phase 20: Cascading World Generation Foundation
- [ ] Phase 21: AI-Assisted Validated Expansion

---

## Current Focus

Procession now has a tiny local playable CLI loop. The next work should improve the playable experience only where it strengthens the underlying living-world simulation.

The project should not drift into being only a terminal text adventure. The CLI is a visibility layer for the Elixir/OTP simulation engine.

Current priorities:

- Clarify what different entity types are allowed to do.
- Improve the playable shell only where it strengthens simulation boundaries.
- Bring AI interaction closer to the core experience through explicit, safe boundaries.
- Keep simulation authority in Elixir.
- Keep AI output validated before it can affect state.
- Improve starter-area world reactivity enough to expose simulation behavior.
- Preserve the long-term path toward active scopes, cascading world generation, and selective spawning.

---

## Architecture Guardrails

### AI is the creative core; Elixir is the authoritative scaffold

AI is central to Procession’s purpose. It provides the creative force behind dynamic dialogue, world expansion, emergent rumors, faction tension, behavior proposals, and cascading content generation.

Elixir/OTP provides the armor and scaffolding that keeps AI output usable, testable, and safe. AI may propose possibilities, but Elixir validates, constrains, supervises, and simulates accepted possibilities.

Procession should not minimize AI. It should contain and structure AI so that its creativity can drive the world without turning the simulation into inconsistent Lovecraftian nonsense  — unless that is the explicit design goal of a validated world, region, faction, entity, or event.

The intended loop is:

1. AI proposes expressive or generative content.
2. Elixir parses and validates the proposal.
3. Validated data becomes memory, behavior metadata, thread state, scope data, or blueprint content.
4. OTP processes simulate the accepted world state.
5. The player experiences the result through CLI, IEx, or future UI adapters.

AI is therefore core to the experience, but not sovereign over the state.

### General simulation rules

- Elixir remains authoritative over simulation state.
- Entities own their state, memory, and behavior metadata.
- `Procession.Game`, `Procession.GameSession`, `Procession.WorldClock`, `Procession.Command`, `Procession.Command.Display`, `Procession.CLI`, and `Procession.Demo` coordinate or adapt; they should not own entity behavior.
- Behavior metadata remains data, not executable code.
- AI-generated content is untrusted until validated.
- Ollama may generate expression, dialogue, rumors, or candidate content, but Elixir decides what actually changes.
- CLI and display formatting are player-facing adapters only.
- Inactive world content should remain blueprint or summary data until activated.
- Do not spawn the whole world as live OTP processes.
- Prefer visible, testable progress over abstract cleanup.

---

## Phase 15: Capability Boundaries & Playability Polish

Phase 15 clarifies what different entity types can do.

The goal is to prevent commands, ticking, travel, and dialogue from treating every entity as if it were an NPC-style actor. This protects the simulation model while making the CLI more understandable.

### Entity capability rules

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

### Gameplay error handling

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

### Tick behavior boundaries

- [ ] Decide which entity types should be ticked in the current simulation.
- [ ] First version should probably tick NPCs and skip player/location/faction autonomous behavior unless explicitly enabled.
- [ ] Keep behavior execution owned by `Entity.tick/1`.
- [ ] Avoid moving ticking rules into command parsing.
- [ ] Add tests proving non-tickable entities are not treated as autonomous actors if filtering is implemented.
- [ ] Keep failed behavior actions visible as structured data.

### CLI and display polish

- [ ] Improve display output to prefer readable names over raw IDs where practical.
- [ ] Improve local entity output in `look`.
- [ ] Improve travel output after movement.
- [ ] Improve error messages for unsupported capabilities.
- [ ] Keep display formatting separate from simulation logic.
- [ ] Add tests for display formatting improvements.

### Demo stability

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

### Documentation

- [ ] Update `docs/USAGE.md` or demo docs with capability limits.
- [ ] Document that the CLI is a thin playability layer.
- [ ] Document that capability rules are intentionally simple for now.
- [ ] Document deferred richer capability metadata.

### Deferred from Phase 15

- [ ] Defer inventory.
- [ ] Defer combat.
- [ ] Defer quests.
- [ ] Defer persistence.
- [ ] Defer AI command parsing.
- [ ] Defer large-world expansion.

---

## Phase 16: AI-Backed NPC Dialogue Through Safe Boundaries

Phase 16 brings AI closer to the playable experience.

The goal is to prove that AI improves NPC interaction while Elixir remains authoritative over state. AI dialogue should make the world feel more alive, but it should not directly mutate memory, behavior, world state, quests, or entity metadata.

### AI dialogue boundary

- [ ] Add an explicit way to request Ollama-backed NPC dialogue.
- [ ] Keep deterministic fake adapter as default for tests.
- [ ] Restrict AI dialogue to talkable NPCs.
- [ ] Reuse the existing `Procession.AI` adapter boundary.
- [ ] Keep command parsing deterministic.
- [ ] Do not use AI to interpret player commands in this phase.
- [ ] Return generated text only.
- [ ] Do not allow AI to directly mutate entity state.
- [ ] Do not allow AI to create behavior metadata in this phase.
- [ ] Add tests using the fake adapter.
- [ ] Add manual docs for trying Ollama locally.

### Prompt context

- [ ] Include NPC name, type, status, location, and traits.
- [ ] Include relevant memories.
- [ ] Include player message.
- [ ] Include current location context if available.
- [ ] Include session/world context only if it is compact and useful.
- [ ] Keep prompts structured and inspectable.
- [ ] Add tests for prompt construction if prompt logic grows.

### Session and command integration

- [ ] Decide the first AI dialogue call shape.
  - Example: `Procession.GameSession.talk_to(session, npc_id, message, adapter: Procession.AI.Ollama)`
- [ ] Keep existing deterministic dialogue behavior available.
- [ ] Decide whether `Procession.Command.run/2` should remain deterministic for now.
- [ ] If CLI support is added, make it explicit.
  - Example: `mix procession.play --ai`
- [ ] Keep CLI deterministic by default unless intentionally changed.
- [ ] Add IEx examples for AI-backed dialogue.

### AI safety and validation

- [ ] Document that AI dialogue is expression, not authority.
- [ ] Document that generated dialogue does not automatically become memory.
- [ ] Document that generated dialogue does not automatically become behavior metadata.
- [ ] Keep all state changes deterministic unless a future validated mutation path is added.
- [ ] Add tests proving AI dialogue does not mutate entity state.

### Deferred from Phase 16

- [ ] Defer AI autonomous planning.
- [ ] Defer AI-generated behavior metadata.
- [ ] Defer AI command interpretation.
- [ ] Defer memory mutation from AI output.
- [ ] Defer quest systems.
- [ ] Defer persistence.

---

## Phase 17: Starter Area Content Depth & World Reactivity

Phase 17 makes the current starter area more interesting while keeping the simulation deterministic and inspectable.

The goal is to improve visible world reactivity. The starter area should feel less like a static demo and more like a small living situation.

### Starter content depth

- [ ] Add richer deterministic starter memories.
- [ ] Add more useful ask-about topics.
- [ ] Add at least one additional visible NPC memory relationship.
- [ ] Add at least one visible world event that can be discovered after `wait`.
- [ ] Improve location descriptions to hint at current tensions.
- [ ] Ensure at least two NPCs have meaningful things to inspect or ask about.
- [ ] Keep demo content deterministic.
- [ ] Add tests for new starter memories and topics.

### Visible world reactivity

- [ ] Add or refine behavior metadata so `wait` creates visible consequences.
- [ ] Ensure successful actions are visible through command/display output.
- [ ] Ensure failed actions remain visible for debugging.
- [ ] Ensure player-facing event inspection can reveal changes.
- [ ] Add tests proving `wait` changes later inspection or event output.
- [ ] Add tests proving playerless behavior affects later player interaction.

### Demo experience

- [ ] Update the demo command list if new useful interactions exist.
- [ ] Add a richer 5-minute demo path.
- [ ] Keep the demo runnable without Ollama.
- [ ] Add optional AI-enhanced demo notes if Phase 16 supports them.
- [ ] Keep the demo focused on simulation behavior, not just prettier text.

### Deferred from Phase 17

- [ ] Defer full quest systems.
- [ ] Defer combat.
- [ ] Defer inventory.
- [ ] Defer save/load.
- [ ] Defer large-world expansion.

---

## Phase 18: Rumor / Thread Prototype

Phase 18 introduces a small world-thread system.

The goal is to track emerging story threads without building a rigid quest system. Threads should help the player follow world activity while preserving the simulation-first design.

### Thread model

- [ ] Define a simple thread data shape.
  - Example fields: `:id`, `:title`, `:state`, `:related_entities`, `:facts_discovered`, `:open_questions`.
- [ ] Keep threads as plain data first.
- [ ] Decide whether threads live in session state, entity memory, or a small separate module.
- [ ] Add a starter thread for the existing demo situation.
  - Example: the mine road, Tobin’s warning, Mira’s concern.
- [ ] Add tests for creating and inspecting thread data.

### Thread discovery

- [ ] Allow player actions to reveal thread facts.
- [ ] Connect existing memories/events to thread discovery where simple.
- [ ] Add a session API for listing known threads.
  - Example: `Procession.GameSession.threads(session)`
- [ ] Add a session API for inspecting one thread.
- [ ] Add command support if useful.
  - Example: `threads`
  - Example: `thread mine road`
- [ ] Add tests for thread discovery through player interaction.

### Thread progression

- [ ] Decide whether `wait` can advance a thread deterministically.
- [ ] Add one small deterministic thread progression.
- [ ] Keep progression inspectable as plain data.
- [ ] Do not create a full quest engine yet.
- [ ] Add tests proving a thread can progress.

### Display and demo

- [ ] Add display formatting for known threads.
- [ ] Add a demo sequence showing thread discovery.
- [ ] Keep output readable but not overly polished.
- [ ] Document that threads are not full quests yet.

### Deferred from Phase 18

- [ ] Defer quest rewards.
- [ ] Defer objectives/checklists unless they naturally emerge.
- [ ] Defer branching quest logic.
- [ ] Defer AI-authored thread progression.
- [ ] Defer persistence.

---

## Phase 19: Active Scope & Selective Simulation

Phase 19 returns to the long-term large-world architecture.

The goal is to formalize the difference between live active content and inactive blueprint/summary content. This prevents large worlds from becoming fully spawned GenServer forests.

### Active scope model

- [ ] Define a first active scope data shape.
  - Example fields: `:scope_id`, `:kind`, `:entity_ids`, `:location_ids`, `:faction_ids`, `:status`.
- [ ] Store active scope information in session state.
- [ ] Keep the first scope model simple and local.
- [ ] Add tests for active scope summary output.
- [ ] Document that active scope is runtime state, not the whole world.

### Scope-aware ticking

- [ ] Update session ticking to tick only active-scope entities if not already doing so.
- [ ] Keep global world ticking available for debugging if useful.
- [ ] Ensure non-active entities are not ticked through the session.
- [ ] Add tests proving session tick only affects active scope.
- [ ] Add tests proving inactive entities remain untouched.
- [ ] Keep tick summaries inspectable.

### Scope lifecycle

- [ ] Add helpers for activating a scope.
- [ ] Add helpers for deactivating a scope.
- [ ] First version may only support the starter scope.
- [ ] Do not implement full lazy generation yet.
- [ ] Add tests for activation/deactivation behavior.
- [ ] Ensure cleanup still stops live session-owned entities.

### Blueprint separation

- [ ] Document the difference between:
  - generated blueprint data
  - active scope summaries
  - live entity processes
- [ ] Avoid storing all future content as live entities.
- [ ] Add small examples in `WORLD_GENERATION.md` if useful.

### Deferred from Phase 19

- [ ] Defer region-scale generation.
- [ ] Defer save/load.
- [ ] Defer background simulation of inactive scopes.
- [ ] Defer full world maps.
- [ ] Defer multi-scope travel unless trivial.

---

## Phase 20: Cascading World Generation Foundation

Phase 20 begins the large-world generation pipeline.

The goal is not to generate everything at once. The goal is to generate broad summaries first, then expand details only when needed.

### World hierarchy

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

### Region summaries

- [ ] Add deterministic region summary generation.
- [ ] Include region name, type, themes, tensions, and known factions.
- [ ] Keep summaries inert.
- [ ] Add tests for region summary shape.
- [ ] Add docs explaining inert region summaries.

### Local scope expansion

- [ ] Add a function for expanding one region/local scope into a detailed blueprint.
- [ ] Validate expanded blueprint before spawning.
- [ ] Spawn only the selected active scope.
- [ ] Add tests proving expansion does not spawn unrelated regions.
- [ ] Add tests proving invalid expansion output is rejected.

### Integration with session

- [ ] Allow a session to hold broader world summary data.
- [ ] Allow a session to activate one expanded local scope.
- [ ] Keep active scope ownership explicit.
- [ ] Add tests for activating generated scope data.

### Deferred from Phase 20

- [ ] Defer AI-generated hierarchy if deterministic generation is not stable.
- [ ] Defer persistence.
- [ ] Defer background inactive-region simulation.
- [ ] Defer large-scale pathfinding.
- [ ] Defer economic/faction simulation.

---

## Phase 21: AI-Assisted Validated Expansion

Phase 21 uses local AI to propose larger world content.

The goal is to let Ollama assist generation without making it authoritative. AI proposes. Elixir validates. Invalid content gets rejected, repaired, or ignored.

### AI expansion boundary

- [ ] Add or extend an AI-assisted generation boundary for region/scope expansion.
- [ ] Keep prompts structured.
- [ ] Keep AI output as untrusted text or parsed data until validated.
- [ ] Reuse existing AI adapter pattern.
- [ ] Ensure tests use fake adapters.
- [ ] Add manual Ollama test instructions.

### Structured output parsing

- [ ] Decide on a simple structured output format.
  - Example: JSON-like maps after parsing.
- [ ] Parse AI output into candidate blueprints.
- [ ] Validate candidate blueprints through existing validation boundaries.
- [ ] Return predictable errors for invalid AI output.
- [ ] Add tests for valid and invalid fake AI outputs.

### Safe content activation

- [ ] Ensure AI-generated content is not spawned until validated.
- [ ] Spawn only selected validated scopes.
- [ ] Keep inactive generated summaries inert.
- [ ] Add tests proving invalid AI content is not spawned.
- [ ] Add tests proving valid AI-assisted content can become an active scope.

### Diagnostics

- [ ] Add simple diagnostics for rejected AI output.
- [ ] Add prompt/response examples for local debugging.
- [ ] Consider Python tooling later for prompt evaluation or generation diagnostics.
- [ ] Do not add Python into the simulation runtime.

### Deferred from Phase 21

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

- [ ] Optional AI-backed NPC dialogue is available through an explicit safe path.
- [ ] AI dialogue is restricted to talkable NPCs.
- [ ] AI prompt context includes relevant NPC/session/player context.
- [ ] AI dialogue returns text only and does not mutate game state directly.
- [ ] Existing deterministic dialogue behavior remains available.
- [ ] Tests use fake adapters and do not require Ollama.
- [ ] Documentation explains deterministic play and AI-backed dialogue.
- [ ] AI planning, AI command parsing, and AI-generated behavior mutation remain deferred.

### Phase 17 is complete when:

- [ ] The starter area has richer deterministic memories or topics.
- [ ] At least one `wait` action creates a visible consequence.
- [ ] Player-facing inspection can reveal new world activity.
- [ ] The demo has a richer but still deterministic play path.
- [ ] Tests prove starter content and visible reactivity.
- [ ] Documentation explains the updated starter-area demo.
- [ ] Quests, combat, inventory, persistence, and large-world expansion remain deferred.

### Phase 18 is complete when:

- [ ] A simple world-thread data model exists.
- [ ] At least one starter thread can be discovered.
- [ ] Player actions can reveal thread facts.
- [ ] Threads can be inspected through session APIs or commands.
- [ ] At least one deterministic thread progression exists if useful.
- [ ] Display output can show known threads.
- [ ] Tests cover thread discovery and inspection.
- [ ] Full quest systems, rewards, branching quests, and AI-authored progression remain deferred.

### Phase 19 is complete when:

- [ ] Active scope is represented as explicit session/runtime data.
- [ ] Session ticking can be limited to active-scope entities.
- [ ] Inactive content is not treated as live simulation.
- [ ] Scope activation/deactivation is tested at a simple level.
- [ ] Cleanup still handles live session-owned entities.
- [ ] Documentation explains active scope versus blueprint versus live process.
- [ ] Region-scale generation, persistence, and inactive background simulation remain deferred.

### Phase 20 is complete when:

- [ ] A cascading world hierarchy shape exists.
- [ ] Region summaries can be generated or represented as inert data.
- [ ] One local scope can be expanded from broader world data.
- [ ] Expanded scope data is validated before spawning.
- [ ] Only selected active scope content becomes live entity processes.
- [ ] Tests prove unrelated regions are not spawned.
- [ ] Documentation explains the broad-to-detailed generation pipeline.
- [ ] AI generation, persistence, and large-scale background simulation remain deferred unless explicitly started.

### Phase 21 is complete when:

- [ ] Local AI can propose region or scope expansion content through a controlled boundary.
- [ ] AI output is parsed into candidate data.
- [ ] Candidate data is validated before use.
- [ ] Invalid AI output returns predictable errors and is not spawned.
- [ ] Valid AI-assisted content can become an active scope.
- [ ] Tests use fake adapters and do not require Ollama.
- [ ] Manual Ollama instructions exist.
- [ ] AI remains non-authoritative over simulation state.