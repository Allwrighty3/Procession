# Roadmap Archive

Historical phase checklists for completed Procession work. Active future planning lives in [ROADMAP.md](ROADMAP.md).

---

### Phase 1: Core Entity System & Message Passing

Phase 1 is complete by the criteria below. The remaining items here are backlog/refinement tasks.

#### Entity lifecycle

- [x] Add a public API for stopping/removing an entity.
- [x] Add tests for stopping an entity.
- [x] Decide what should happen if an entity is started with an ID that already exists.
- [x] Add tests for duplicate entity IDs.
- [x] Add a helper for checking whether an entity exists in the registry.

#### Entity identity and lookup

- [x] Add a consistent entity ID strategy.
  - Runtime IDs use strings.
  - Generated IDs use prefixes like `npc_`, `loc_`, `faction_`, and `mem_`.
  - Some older tests may still use atoms during migration.
- [x] Decide whether entity IDs should be atoms, strings, or another format.
- [x] Add helper functions for looking up entities by ID.
- [x] Add helper functions for listing active entities.

#### Entity communication

- [ ] Add support for typed messages beyond basic `:message` and `:dialogue`.
- [ ] Define a small message schema.
  - Example fields: `:from`, `:to`, `:type`, `:content`, `:importance`, `:timestamp`.

#### Entity state

- [ ] Add a cleaner state update API for common changes.
  - [x] Status updates: `Entity.set_status/2`
  - [x] Location updates: `Entity.move_to/2`
  - [x] Trait updates: `Entity.set_trait/3`
  - [x] Entity metadata updates: `Entity.set_metadata/3`
  - [ ] Relationship updates
- [ ] Decide which fields belong directly on an entity and which should become separate systems later.

#### Supervision and fault tolerance

- [ ] Decide whether restarted entities should keep state, reset state, or reload state.
- [x] Add a basic crash/recovery test for the `DynamicSupervisor`.
- [ ] Decide whether persistence is needed before Phase 3 or can wait.

---

### Phase 2: Hierarchical Memory System

Phase 2 is complete by the criteria below. The remaining items here are backlog/refinement tasks.

#### Memory structure

- [x] Finalize the memory entry schema.
  - Current fields include `:content`, `:type`, `:importance`, `:timestamp`, and `:from`.
- [x] Decide whether memory entries should include an ID.
- [x] Add optional metadata fields.
  - Example: `:source`, `:tags`, `:location`, `:related_entities`.
- [x] Decide whether memories should remain plain maps or become a struct.

#### Memory promotion

- [x] Review current promotion behavior:
  - short memory overflows into medium memory.
  - medium memory overflows into long memory.
- [ ] Decide whether promotion should happen purely by capacity or also by importance.
- [ ] Add importance-based promotion rules.
- [ ] Add tests for high-importance memories being retained longer.
- [ ] Add tests for low-importance memories being dropped first.
- [ ] Decide whether long memory should ever expire.

#### Memory retrieval

- [ ] Improve keyword search beyond basic substring matching.
- [x] Add search across memory metadata.
  - Example: search by type, source, sender, tags, or location.
- [x] Add tests for searching by memory type.
- [x] Add tests for searching by sender.
- [x] Add tests for searching by tag.
- [x] Add a `recall_recent/2` helper.
- [x] Add a `recall_important/2` helper.
- [x] Add a `recall_by_type/2` helper.

#### Entity memory API

- [x] Add basic entity-facing recall APIs.
  - Implemented: `Entity.recall/2`
  - Implemented: `Entity.recall_all/1`
- [x] Add targeted entity-facing recall APIs.
  - Example: `Entity.recall_recent(id, count)`.
  - Example: `Entity.recall_by_type(id, :dialogue)`.
  - Example: `Entity.recall_important(id, minimum_importance)`.
- [x] Add tests for each entity recall helper.
- [ ] Decide whether `recall_all/1` should return all memories forever or require a limit.

#### Memory ordering

- [x] Confirm desired ordering for all memory layers.
  - Current behavior favors newest memories first.
- [ ] Decide whether search results should preserve memory priority order.
- [ ] Decide whether search results should rank by recency, importance, or both.
- [ ] Add tests for search result ordering.

#### Long-term memory behavior

- [ ] Decide what long-term memory means in gameplay terms.
- [ ] Add a rule for preserving important long-term memories.
- [ ] Add a rule for forgetting less important long-term memories.
- [ ] Add tests for long-memory limits and priority behavior.
- [ ] Consider whether long memory should eventually be summarized.

#### Summarization preparation

- [ ] Add a placeholder design for memory summarization.
- [ ] Decide when summaries should be created.
  - Example: when medium memory overflows.
  - Example: when long memory reaches its cap.
- [ ] Decide whether summaries should be generated locally by deterministic code first.
- [ ] Delay LLM-generated summaries until Phase 3.

#### Persistence preparation

- [ ] Decide whether memory should be persisted to disk.
- [ ] Decide on a simple local persistence format.
  - Example: JSON, ETS dump, DETS, SQLite, or plain files.
- [ ] Add serialization helpers for memory entries.
- [ ] Add tests for memory serialization.

#### Debugging and inspection

- [x] Add a simple way to inspect memory counts per entity.
  - Example: `%{short: 10, medium: 50, long: 200}`.
- [x] Add an entity API like `Entity.memory_summary(id)`.

---

### Phase 3: Local AI Integration with Ollama

Phase 3 should add a small, local AI boundary before any entity directly depends on an LLM. The goal is to make AI calls possible, testable, replaceable, and fully local.

#### AI boundary

- [x] Add a small `Procession.AI` module as the public boundary for AI requests.
- [x] Define a simple request function.
  - Example: `Procession.AI.generate(prompt, opts \\ [])`
- [x] Standardize return values.
  - Example: `{:ok, response_text}` or `{:error, reason}`
- [x] Keep the AI boundary separate from entity and memory modules.

#### Adapter design

- [x] Define a simple adapter behavior for AI backends.
  - Example: `generate(prompt, opts)`.
- [x] Add a fake adapter for tests and development.
- [x] Add an Ollama adapter only after the fake adapter works.
- [x] Keep adapter selection simple.
  - Example: pass adapter through opts first.
  - Defer application config until needed.
- [x] Avoid adding a supervised AI process unless there is a clear need.

#### Ollama integration

- [x] Decide the first local model to target.
  - Example: `llama3.2`, `mistral`, or another small local model.
- [x] Add a minimal Ollama client that calls the local HTTP API.
- [x] Support only the simplest text generation request first.
- [x] Handle basic connection failures.
  - Example: Ollama not running.
  - Example: model not installed.
- [x] Add optional/manual test instructions for testing against a real local Ollama server.

#### Prompt structure

- [x] Define a small prompt-building helper.
- [x] Start with plain strings before introducing complex prompt structs.
- [x] Add a basic system/context convention.
  - Example: world context, entity state, relevant memories, player input.
- [x] Keep prompts request-based.

#### Entity integration preparation

- [x] Decide the first entity AI use case.
  - Example: generate a short NPC response.
- [x] Add an explicit entity-facing function only after the AI boundary works.
  - Example: `Entity.generate_response(id, player_message)`.
- [x] Include only structured entity state and selected memories in the request.
- [x] Keep AI output as data returned to the caller first.

#### Memory integration preparation

- [x] Decide how many memories should be included in an AI request.
  - Example: recent 5 plus important memories.
- [x] Add a helper for selecting AI-relevant memories.

#### Future refinements

- [ ] Add configurable model names.
- [ ] Add request timeouts.
- [ ] Add structured output parsing.
- [ ] Add response validation.
- [ ] Add prompt templates.
- [ ] Add AI-generated memory summaries.
- [ ] Add richer NPC behavior using AI-generated intent or dialogue.
- [ ] Consider a supervised AI worker only if concurrent calls, rate limiting, or queueing become necessary.

---

### Phase 4: Procedural Game Generator

Phase 4 should add a small procedural world generator that can create a playable starting world from a text prompt. The generator should use the existing entity system, memory system, and local AI boundary without turning world generation into a giant unmanaged blob.

The first goal is not to generate a massive world. The first goal is to generate a small, structured world with a few locations, NPCs, factions, relationships, and starter memories.

#### Generator boundary

- [x] Add a small `Procession.Generator` module as the public boundary for world generation.
- [x] Define a simple request function.
  - Example: `Procession.Generator.generate_world(prompt, opts \\ [])`
- [x] Standardize return values.
  - Example: `{:ok, world_blueprint}` or `{:error, reason}`
- [x] Keep generator logic separate from entity processes.
- [x] Do not start GenServer entities directly from the first generator function.
- [x] Add tests for the public generator API using deterministic input.

#### World blueprint structure

- [x] Define a simple world blueprint map before introducing complex structs.
- [x] Include a world name or title.
- [x] Include a short world description.
- [x] Include a small list of generated locations.
- [x] Include a small list of generated NPCs.
- [x] Include a small list of generated factions.
- [x] Include relationship links between generated entities.
- [x] Include starter memories or rumors for selected NPCs.

#### Deterministic starter generator

- [x] Add a deterministic generator that does not require Ollama.
- [x] Use this deterministic generator for tests.
- [x] Generate a tiny default world from a prompt.
  - Example: 3 locations, 3 NPCs, 1 faction.
- [x] Use string IDs compatible with the existing ID conventions.
  - Example: `loc_`, `npc_`, `faction_`.

#### AI-assisted generation preparation

- [x] Add a generator prompt helper.
- [x] Keep generator prompts plain strings at first.
- [x] Include clear output expectations in the prompt.
- [x] Ask the AI for small structured output only.

#### Ollama-assisted generation

- [x] Add an optional AI generation path using `Procession.AI.generate/2`.
- [x] Use the existing AI adapter boundary instead of calling Ollama directly.
- [x] Keep the first AI-assisted result small.
- [ ] Handle invalid or incomplete AI output predictably.
- [ ] Return errors instead of crashing on malformed AI responses.
- [x] Add tests that do not require Ollama to be installed or running.
- [x] Add optional/manual IEx instructions for testing AI-assisted generation locally.

#### Blueprint validation

- [x] Add simple validation for generated blueprints.
- [x] Validate required top-level fields.
  - Example: `:name`, `:description`, `:locations`, `:npcs`, `:factions`.
- [x] Validate that entity IDs are present and unique.
- [x] Validate that NPC locations refer to known locations.
- [x] Validate that relationships refer to known entity IDs.
- [x] Validate starter memories have content and type.

#### Spawning generated worlds

- [x] Add a separate function for spawning a blueprint into live entity processes.
  - Example: `Procession.Generator.spawn_world(world_blueprint)`
- [x] Keep generation and spawning separate.
- [x] Start generated locations through `EntitySupervisor`.
- [x] Start generated NPCs through `EntitySupervisor`.
- [x] Start generated factions through `EntitySupervisor`.
- [x] Attach starter memories only after entities are created.
- [x] Return a summary of created entities.

#### Starter memories and relationships

- [x] Use existing entity message/memory behavior where possible.
- [x] Add starter rumors, observations, or faction opinions as memories.

#### Future refinements

- [ ] Add configurable world sizes.
- [ ] Add seeded random generation.
- [ ] Add biome, culture, conflict, and economy options.
- [ ] Add structured JSON parsing for AI-generated blueprints.
- [ ] Add richer faction goals and relationships.
- [ ] Add generated quests.
- [ ] Add generated location descriptions.
- [ ] Add generated NPC personality traits.
- [ ] Add generated long-term memories.
- [ ] Add persistence for generated worlds.
- [ ] Add Phoenix LiveView controls for generating and inspecting worlds.

---

### Phase 5: Gameplay Systems & Polish

Phase 5 should turn the generated world into something the player can inspect, interact with, and eventually play. The goal is not to build a full RPG engine immediately. The first goal is to create a tiny player-facing gameplay boundary that uses the existing entity, memory, generator, and AI systems.

Phase 5 should stay small, local, testable, and OTP-friendly. Build public gameplay APIs first, then add richer systems only after the basic loop works.

#### Gameplay boundary

- [x] Add a small `Procession.Game` module as the public boundary for player-facing gameplay.
- [x] Keep gameplay orchestration separate from `Entity`, `Memory`, `Generator`, and `AI`.
- [x] Standardize return values.
  - Example: `{:ok, result}` or `{:error, reason}`

#### World inspection

- [x] Add a basic function for inspecting a live entity.
  - Example: `Procession.Game.look(entity_id)`
- [x] Return a player-friendly summary of entity state.
  - Example fields: `:id`, `:name`, `:type`, `:location`, `:status`, `:traits`, `:relationships`, `:memory_summary`.
- [x] Handle missing entities predictably.
  - Example: `{:error, :entity_not_found}`
- [x] Keep the first inspection result as plain data, not formatted prose.

#### Generated world gameplay setup

- [x] Add a helper for creating a playable test world.
  - Example: `Procession.Game.new_game(prompt)`
- [x] Use the deterministic generator first.
- [x] Validate the generated blueprint before spawning.
- [x] Spawn the generated world through `Procession.Generator.spawn_world/1`.
- [x] Return a summary that includes the world name and created entity IDs.
- [x] Do not use AI generation for the first playable setup path.

#### Player actions

- [x] Define a tiny player action API.
  - Example: `Procession.Game.perform(action, opts)`
- [x] Start with one or two simple deterministic actions.
  - Example: `:look`
  - Example: `:talk`
  - Example: `:move`
- [x] Keep actions as plain data before introducing command parsing.
- [x] Return action results without mutating more state than necessary.
- [x] Handle invalid actions predictably.

#### Dialogue

- [x] Add a simple player-to-NPC dialogue helper.
  - Example: `Procession.Game.talk_to(npc_id, player_message, opts \\ [])`
- [x] Use `Entity.generate_response/3` for optional AI-backed dialogue.
- [x] Support deterministic fake-adapter dialogue in tests.
- [x] Keep generated dialogue as returned data first.

#### Memory-driven interaction

- [x] Add a simple helper for recalling what an NPC knows.
  - Example: `Procession.Game.ask_about(npc_id, topic)`
- [x] Use existing entity recall helpers.
- [x] Keep recall deterministic before adding AI summarization.
- [x] Return matching memories as data.

#### Gameplay loop preparation

- [x] Define the first tiny gameplay loop.
  - Example: create world, inspect NPC, talk to NPC, inspect memory.

#### Autonomous world activity

Autonomous world activity should support the core Procession vision: entities are lightweight OTP actors that can act from their own state, memory, traits, metadata, and relationships.

The deterministic starter world may include named example NPCs for tests and IEx demos, but the autonomous behavior system must not depend on those names. Future AI-generated worlds may not include Mira, Tobin, Elin, or any specific hardcoded entity.

The intended model is:

- The world generator creates entities.
- Generated entities may include behavior metadata.
- Entities own their possible behaviors.
- `Procession.Game.tick_all_live_entities/0` coordinates a world tick.
- Each tick asks live entities whether they act.
- Entities inspect their own state and metadata before acting.
- Playerless actions happen through normal entity messaging.
- Messages become memories through the existing memory system.
- The game layer returns a summary of what happened, but does not own the world’s plot logic.

The current scripted tick implementation is treated as a spike/proof-of-concept. It proved that playerless world activity can create memories, but it should not grow into a global event engine.

Long-term, behavior metadata should be generated as part of the world blueprint. Deterministic behavior examples exist only as test fixtures. The engine should validate and execute a small safe behavior schema rather than hardcoding story-specific actions.

- [x] Move autonomous behavior out of hardcoded game-level event scripts.
- [x] Add generic behavior metadata support for generated entities.
  - Example: `metadata.behaviors`
- [x] Allow deterministic generator output to include one sample behavior for testing.
- [x] Keep behavior execution generic and independent of specific NPC names.
- [x] Add an entity-level tick API.
  - Example: `Procession.Entity.tick(entity_id)`
- [x] Let ticked entities inspect their own metadata before acting.
- [x] Support one deterministic behavior action first.
  - Example: `:send_message`
- [x] Use existing `Entity.send_to/3` for NPC-to-NPC actions.
- [x] Make playerless actions create memories through normal message delivery.
- [x] Keep `Procession.Game.tick_all_live_entities/0` as a coordinator, not the source of behavior.
- [x] Make `Game.tick_all_live_entities/0` discover live entities instead of assuming specific IDs.
- [x] Return a summary of entity-driven actions from each tick.
- [x] Keep the first version manually triggered from IEx.
- [x] Defer timers, schedulers, background loops, complex NPC goals, and AI-driven autonomy.

#### Future refinements

- [ ] Add quest generation.
- [ ] Add inventory.
- [ ] Add items and item ownership.
- [ ] Add location exits and travel restrictions.
- [ ] Add faction reputation.
- [ ] Add NPC goals.
- [ ] Add conflict/combat only after basic interaction works.
- [ ] Add persistence for active game sessions.
- [ ] Add Phoenix LiveView UI for inspecting and interacting with the world.

---

### Phase 6: Entity Autonomy & Behavior Schema

Phase 6 turns the first entity-driven behavior proof into a safer, more general autonomy layer.

The goal is not full AI agency yet. The goal is to define, validate, and execute a small behavior schema that generated entities can carry safely.

Long-term, behavior metadata should be generated as part of the world blueprint. Deterministic behavior examples exist only as test fixtures. The engine should validate and execute a small safe behavior schema rather than hardcoding story-specific actions.

AI-generated worlds will eventually produce behavior metadata, but that metadata must remain data, not executable code.

#### Behavior schema foundation

- [x] Add a dedicated behavior module.
  - Example: `Procession.Behavior`
- [x] Define the supported behavior data shape.
  - Example: `%{trigger: :world_tick, action: :send_message, ...}`
- [x] Keep behavior schemas as plain maps for now.
- [x] Avoid macros, DSLs, or custom structs until the schema settles.
- [x] Document that behavior metadata is generated data, not executable code.
- [x] Keep behavior schema logic independent from specific NPC names.
- [x] Keep deterministic behavior fixtures available for stable tests.

#### Behavior validation

- [x] Add validation for behavior metadata.
  - Example: `Procession.Behavior.validate/1`
- [x] Validate that every behavior has a supported `:trigger`.
- [x] Validate that every behavior has a supported `:action`.
- [x] Validate required fields for `:send_message`.
  - Example: `:to`, `:content`
- [ ] Validate required fields for future behavior actions.
- [x] Reject malformed behavior metadata predictably.
  - Example: `{:error, {:invalid_behavior, behavior}}`
- [x] Reject unsupported behavior actions predictably.
  - Example: `{:error, {:unsupported_behavior_action, action}}`
- [x] Reject unsupported behavior triggers predictably.
  - Example: `{:error, {:unsupported_behavior_trigger, trigger}}`
- [x] Ensure validation never executes behavior.

#### Blueprint integration

- [x] Validate NPC behavior metadata during blueprint validation.
- [x] Keep behavior validation inside generator validation small and explicit.
- [x] Ensure invalid generated behavior metadata prevents unsafe world spawning.
- [x] Preserve valid behavior metadata when spawning generated NPCs.

#### Behavior execution

- [x] Route entity tick behavior execution through the behavior module.
  - Example: `Procession.Behavior.execute(entity_state, behavior)`
- [x] Keep `Procession.Entity.tick/1` as the entity-level tick API.
- [x] Keep `Entity.tick/1` responsible for reading behavior metadata from entity state.
- [x] Keep behavior execution generic across entity IDs.
- [x] Continue supporting the existing `:send_message` action.
- [x] Ensure `:send_message` uses `Entity.send_to/3`.
- [x] Ensure messages created by behavior execution become memories normally.
- [x] Return structured action results from behavior execution.
  - Example: `%{status: :ok, action: :send_message, from: ..., to: ...}`
- [x] Return structured errors for failed behavior execution.

#### Second safe behavior action

- [x] Add one additional deterministic behavior action.
  - Recommended first option: `:change_status`
- [x] Define the schema for `:change_status`.
  - Example: `%{trigger: :world_tick, action: :change_status, status: :alert}`
- [x] Validate required fields for `:change_status`.
- [x] Execute `:change_status` without an entity GenServer calling itself.
- [x] Update entity state directly during the tick when appropriate.
- [x] Return a structured action summary for `:change_status`.
  - Example: `%{status: :ok, action: :change_status, entity_id: ..., new_status: :alert}`
- [x] Add one deterministic fixture behavior using `:change_status`.

---

### Phase 7: World Simulation Clock & Scheduling

Phase 7 introduces a controlled world simulation cadence.

The goal is to move from manually calling `Procession.Game.tick_all_live_entities/0` toward a simple, testable simulation loop without turning the project into a runaway background-agent circus.

Scheduling should coordinate existing entity ticks; it should not replace entity-owned behavior.

#### Clock boundary

- [x] Add a dedicated world clock module.
  - Example: `Procession.WorldClock`
- [x] Keep the clock separate from `Procession.Game`.
- [x] Keep `Procession.Game.tick_all_live_entities/0` usable as a direct manual tick.
- [x] Make the clock call the existing gameplay/world tick boundary.

#### Manual clock process

- [x] Start with a manually controlled GenServer.
  - Example: `Procession.WorldClock.start_link/1`
- [x] Add a public API for triggering one tick through the clock.
  - Example: `Procession.WorldClock.tick(clock_pid)`
- [x] Store the latest tick summary in clock state.
- [x] Expose the latest tick summary.
  - Example: `Procession.WorldClock.last_tick(clock_pid)`
- [x] Track the total number of ticks coordinated by the clock.

#### Supervision

- [x] Add the world clock to supervision only after the manual clock API works.
- [x] Decide whether the clock is always started or started only for a game session.
- [x] Prevent duplicate world clocks from running accidentally.

#### Optional interval ticking

- [x] Add optional interval-based ticking.
  - Example: `interval_ms: 1_000`
- [x] Keep interval ticking disabled by default.
- [x] Add a way to start interval ticking.
- [x] Add a way to stop interval ticking.
- [x] Ensure scheduled ticks do not overlap.
- [x] Ensure interval ticking can be tested deterministically.

#### Tick result handling

- [x] Keep tick summaries as plain data.
- [x] Include total entities ticked.
- [x] Include successful entity actions.
- [x] Include failed entity actions.
- [x] Include clock tick count.
- [x] Include monotonic clock tick number.
- [x] Keep recent summaries inspectable from IEx.

#### Failure isolation

- [x] Make sure one entity tick failure does not crash the full world tick.
- [x] Collect failed tick results as data.

---

### Phase 8: Game Session & Active Entity Ownership

Phase 8 introduces a runtime session boundary.

The goal is to stop treating all live entities as one global game and start tracking which entities belong to a specific active play session. This prepares Procession for larger worlds where only the current active scope should be live, while distant or inactive content can remain blueprint data.

This phase should not add persistence, command parsing, Phoenix LiveView, complex travel, or scoped world expansion yet. The first goal is ownership and cleanup.

#### Session boundary

* [x] Add a dedicated game session module.
  * Example: `Procession.GameSession`
* [x] Implement the session as a GenServer.
* [x] Keep `Procession.GameSession` separate from `Procession.Game`.
* [x] Keep `Procession.Game` as the gameplay API boundary for now.
* [x] Keep `Procession.WorldClock` as the clock/scheduling boundary.

#### Session state

* [x] Define simple session state.

  * Example fields: `:session_id`, `:world`, `:active_entities`, `:active_scope`, `:status`.
* [x] Generate stable string session IDs.

  * Example: `session_...`
* [x] Store the current generated game summary in session state.
* [x] Store active entity IDs owned by the session.
* [x] Track session status.

  * Example: `:new`, `:active`, `:cleaned_up`.
* [x] Expose a public session summary API.

  * Example: `Procession.GameSession.summary(session)`

#### Starting a generated game in a session

* [x] Add a session API for creating a new game.

  * Example: `Procession.GameSession.new_game(session, prompt)`
* [x] Delegate deterministic game creation to `Procession.Game.new_game/1`.
* [x] Store the returned game summary in session state.
* [x] Store all generated entity IDs as session-owned active entities.

  * Example: locations + NPCs + factions.
* [x] Return a player-facing session/game summary.
* [x] Keep generated world spawning behavior unchanged.
* [x] Do not introduce scoped spawning yet.

#### Active entity ownership

* [x] Add an API for listing active session entities.

  * Example: `Procession.GameSession.active_entities(session)`
* [x] Add an API for checking whether an entity belongs to a session.

  * Example: `Procession.GameSession.owns_entity?(session, entity_id)`

#### Session cleanup

* [x] Add a cleanup API.

  * Example: `Procession.GameSession.cleanup(session)`
* [x] Stop all active entities owned by the session.
* [x] Mark the session as cleaned up.
* [x] Clear or retain owned entity IDs intentionally.

  * Recommended first version: retain IDs for inspection, but mark session as cleaned up.
* [x] Make cleanup safe to call more than once.
* [x] Return a cleanup summary as plain data.

  * Example: `%{stopped: [...], missing: [...], status: :cleaned_up}`

#### Session and clock relationship

* [x] Decide how sessions relate to the existing supervised world clock.
* [x] Keep the first version simple.

  * Recommended first version: session does not own a private clock.

---

### Phase 9: Session-Aware Gameplay API

Phase 9 routes gameplay actions through a game session.

The goal is to make player-facing actions aware of session ownership before adding command parsing or UI. This prevents future gameplay from depending on global entity lookup alone.

This phase should keep the existing `Procession.Game` APIs working. Session-aware APIs should wrap or delegate to existing gameplay functions first.

#### Session gameplay boundary

* [x] Add session-aware gameplay helpers.

  * Example: `Procession.GameSession.look(session, entity_id)`
  * Example: `Procession.GameSession.ask_about(session, entity_id, topic)`
  * Example: `Procession.GameSession.talk_to(session, entity_id, message, opts \\ [])`
* [x] Keep existing `Procession.Game.look/1`, `ask_about/2`, and `talk_to/3` usable.
* [x] Delegate to `Procession.Game` where possible.
* [x] Require target entities to belong to the session.
* [x] Return predictable errors for entities outside the session.

  * Example: `{:error, :entity_not_in_session}`

#### Session-aware ticking

* [x] Add a session tick API.

  * Example: `Procession.GameSession.tick(session)`
* [x] First version may delegate to `Procession.Game.tick_all_live_entities/0`.
* [x] Document that session tick is not yet scoped to session-owned entities unless implemented.
* [x] Return the tick summary as plain data.
* [x] Store the latest tick summary in session state if useful.
* [x] Do not duplicate entity tick logic inside `GameSession`.

#### Session event inspection

* [x] Add session-aware recent event inspection.

  * Example: `Procession.GameSession.recent_events(session, entity_id)`
* [x] Require the entity to belong to the session.
* [x] Delegate to existing event/memory APIs where possible.
* [x] Return predictable errors for non-session entities.

#### Session action API

* [x] Add a generic session action helper if useful.

  * Example: `Procession.GameSession.perform(session, :look, entity_id: "npc_mira")`
* [x] Keep actions as atoms and keyword options.
* [x] Do not parse text commands yet.
* [x] Delegate existing player actions to session-aware helpers.
* [x] Return predictable errors for invalid actions.

#### Session summary improvements

* [x] Include active entity counts in session summary.
* [x] Include world name or generated game name in session summary.
* [x] Include session status.
* [x] Include last tick summary if stored.
* [x] Keep summary as plain data.

---

### Phase 10: Player Entity & Location Context

Phase 10 introduces the player as explicit game state.

The goal is to stop treating the player as an implied caller and start representing the player inside the active session. This enables natural commands like `look`, travel, inventory, player memory, and location-aware interaction later.

This phase should keep the first player model small and deterministic.

#### Player entity foundation

* [x] Decide whether the player should be a normal `Procession.Entity` process or session state first.

  * Recommended first version: player as a normal entity process owned by the session.
* [x] Add a player ID convention.

  * Example: `player_main` or generated `player_...`
* [x] Add a helper for starting a player entity.

  * Example: `EntitySupervisor.start_player/2` if useful.
* [x] Give the player a name, location, status, and metadata.
* [x] Keep player memory support available through the existing entity memory system.

#### Entity type and capability boundaries

* [x] Clarify that all actors may be entities, but not all entities are actors.

  * NPCs and players are actors.
  * Locations, factions, regions, and world concepts may be entities without acting independently.
* [x] Keep `Procession.Entity` as the generic live entity process for now.
* [x] Avoid creating separate supervisors for each entity type in this phase.
* [ ] Add minimal type-based capability rules before command parsing depends on broad entity assumptions.

  * Example: NPCs are talkable.
  * Example: players are movable.
  * Example: locations are inspectable but not talkable.
  * Example: factions are inspectable/relatable but not talkable or directly tickable.
* [ ] Decide whether capability checks should start as private helpers or a small module.

  * Example: `Procession.EntityCapabilities`
  * Simpler first version: private helpers such as `talkable?/1`, `movable?/1`, or `tickable?/1`
* [ ] Ensure gameplay APIs return predictable errors for unsupported entity capabilities.

  * Example: `{:error, :entity_not_talkable}`
  * Example: `{:error, :entity_not_movable}`
  * Example: `{:error, :entity_not_tickable}`
* [ ] Keep capability checks separate from text command parsing.


#### Session player ownership

* [x] Add player ID to session state.
* [x] Add a session API for fetching the current player.

  * Example: `Procession.GameSession.player(session)`
* [x] Add a session API for fetching player location.

  * Example: `Procession.GameSession.player_location(session)`
* [x] Include the player in session cleanup.

#### Location context

* [x] Add a helper for looking at the player's current location.

  * Example: `Procession.GameSession.look(session)`
* [x] Keep `look(session, entity_id)` available for specific targets.
* [x] Return current location summary when no target is provided.
* [x] Include known NPCs or entities at the current location if simple.
* [x] Add predictable errors when the player has no valid location.

#### Local entity discovery

* [x] Add a helper for listing entities at the player's current location.

  * Example: `Procession.GameSession.local_entities(session)`
* [x] Use live entity state to determine locations.
* [x] Limit results to session-owned entities.

#### Player memory preparation

* [x] Decide whether player actions should create memories immediately.
* [x] First version may avoid automatic player memory.
* [ ] Add a basic player memory example only if useful.
* [x] Defer richer journaling or quest logs.

---

### Phase 11: Deterministic Command Parser

Phase 11 adds a small text command boundary.

The goal is to make the game playable through simple text commands without adding Phoenix, a full CLI, or AI-driven command interpretation yet.

The parser should translate strings into existing session-aware gameplay APIs. It should not own gameplay logic.

#### Command boundary

* [x] Add a command module.

  * Example: `Procession.Command`
* [x] Define a public command API.

  * Example: `Procession.Command.run(session, command_text)`
* [x] Require command input to be a binary string.
* [x] Return predictable errors for invalid input.

  * Example: `{:error, :invalid_command}`
* [x] Keep command parsing deterministic.
* [x] Do not call AI for command parsing.

#### Basic command support

* [x] Support `look`.

  * Looks at the player's current location.
* [x] Support `look at <target>`.

  * Looks at a session-owned entity by name or ID.
* [x] Support `ask <npc> about <topic>`.
* [x] Support `talk to <npc>: <message>`.
* [x] Support `wait`.

  * Coordinates one session/world tick.
* [x] Support `events for <entity>`.

  * Shows recent events for a session-owned entity.

#### Entity name resolution

* [x] Add simple entity name lookup within a session.
* [x] Match exact entity IDs first.
* [x] Match entity names second.
* [x] Limit lookup to session-owned entities.
* [x] Return predictable errors for ambiguous names.

  * Example: `{:error, {:ambiguous_entity, matches}}`
* [x] Return predictable errors for unknown names.

  * Example: `{:error, :entity_not_found}`

#### Command result formatting

* [x] Return command results as plain data first.
* [x] Avoid human-readable prose formatting until command data is stable.
* [x] Use consistent result shapes.

  * Example: `{:ok, %{command: :look, result: summary}}`

---

### Phase 12: Basic Travel & Active Scope Preparation

Phase 12 adds simple location movement and prepares for active scopes.

The goal is not full maps or pathfinding. The goal is to let the player move between known locations in the starter world using simple deterministic exits.

#### Location exits

* [x] Decide how location exits are represented.

  * Recommended first version: location metadata.
  * Example: `metadata.exits`
* [x] Define a simple exit shape.

  * Example: `%{to: "loc_silent_mine", label: "mine road"}`
* [x] Add deterministic exits to the starter generated world.
* [x] Validate that exit destinations reference known locations.
* [x] Do not add pathfinding yet.
* [x] Do not add travel time yet unless trivial.

#### Player movement

* [x] Add a session-aware movement API.

  * Example: `Procession.GameSession.travel(session, destination)`
* [x] Require the player entity to exist.
* [x] Require the destination to be reachable from the current location.
* [x] Update player location through existing entity state APIs.
* [x] Return a plain movement summary.

  * Example: `%{from: "loc_a", to: "loc_b"}`
* [x] Return predictable errors for unreachable destinations.
* [x] Return predictable errors for unknown destinations.

#### Travel commands

* [x] Add command support for travel.

  * Example: `go to Silent Mine`
  * Example: `travel to Crossroads`
* [x] Resolve destination by location ID or name.
* [x] Require the destination to be reachable.

#### Location-relative gameplay

* [x] Update `look` to show the player's current location after travel.
* [x] Update local entity listing after travel.
* [x] Ensure entities from other locations are not shown as local.

#### Active scope preparation

* [x] Add a simple active scope concept to session state if useful.

  * Example: `active_scope: "scope_starter_area"`
* [x] Keep active scope as metadata or plain data first.
* [x] Do not implement lazy spawning yet.

---

### Phase 13: First Playable Vertical Slice

Phase 13 packages the existing systems into a tiny playable loop.

The goal is to make Procession playable for 5-10 minutes through deterministic commands in IEx. This is not the final UI, not a full game, and not a content-complete experience. It is the first cohesive prototype.

#### Vertical slice setup

* [x] Add a helper for starting the first playable prototype.

  * Example: `Procession.GameSession.start_demo/1`
  * Or keep setup as documented IEx commands if a helper is premature.
* [x] Create a deterministic game session.
* [x] Create a player entity.
* [x] Spawn the starter world.
* [x] Track active session entities.
* [x] Ensure player starts at a valid location.
* [x] Return a useful startup summary.

#### Minimum playable command loop

* [x] Ensure the player can run `look`.
* [x] Ensure the player can run `look at <npc>`.
* [x] Ensure the player can run `ask <npc> about <topic>`.
* [x] Ensure the player can run `talk to <npc>: <message>`.
* [x] Ensure the player can run `wait`.
* [x] Ensure the player can inspect recent events.
* [x] Ensure the player can travel between starter locations.

#### World reactivity

* [x] Ensure `wait` triggers world ticking.
* [x] Ensure NPC behavior can create visible events or memories.
* [x] Ensure failed NPC behavior remains visible as structured data.
* [x] Ensure the clock is not required for manual play.
* [x] Optionally allow interval ticking during the demo.

#### Demo content expectations

* [x] Keep demo content deterministic.
* [x] Use the current starter world unless a small content update is needed.
* [x] Ensure at least one NPC has useful memory to ask about.
* [x] Ensure at least one NPC behavior creates a visible change.
* [x] Ensure at least two locations are reachable.

#### Result shaping

* [x] Decide whether command results should remain raw data or include simple display text.
* [x] If display text is added, keep it separate from core gameplay state.
* [x] Add small formatting helpers only if needed for playability.
* [x] Do not let formatting own gameplay logic.

#### Documentation and demo script

* [x] Add a documented 5-minute IEx demo script.
* [x] Include setup commands.
* [x] Include at least one `look`.
* [x] Include at least one NPC interaction.
* [x] Include at least one `wait`.
* [x] Include at least one travel command.
* [x] Include cleanup instructions.

---

### Phase 14: Tiny Local CLI Loop

Phase 14 adds a simple local terminal play loop.

The goal is to make the vertical slice playable without manually calling IEx functions. This should remain local, zero-budget, and small.

#### CLI entry point

* [x] Decide the simplest CLI entry point.

  * Example: custom Mix task `mix procession.play`
* [x] Add a Mix task for starting the playable demo.

  * Example: `Mix.Tasks.Procession.Play`
* [x] Start or reuse a game session.
* [x] Create the deterministic starter world.
* [x] Create the player entity.
* [x] Print a short intro.
* [x] Accept typed commands from stdin.
* [x] Add tests for CLI setup where practical.
* [x] Keep command parsing delegated to `Procession.Command`.

#### CLI command loop

* [x] Read player input line by line.
* [x] Send commands to the deterministic command parser.
* [x] Print command results in a readable format.
* [x] Support `help`.
* [x] Support `quit`.
* [x] Keep the loop local and synchronous.

#### Simple output formatting

* [x] Add basic display formatting for look results.
* [x] Add basic display formatting for memory/event results.
* [x] Add basic display formatting for travel results.
* [x] Add basic display formatting for errors.
* [x] Keep formatting separate from simulation logic.

#### Safety and cleanup

* [x] Stop interval ticking when quitting if it was started.
* [x] Clean up session-owned entities on quit.
* [x] Handle invalid commands without crashing the loop.
* [ ] Handle Ctrl+C as gracefully as practical.

---

## Phase 15: Capability Boundaries & Playability Polish

Phase 15 clarifies what different entity types can do.

The goal is to prevent commands, ticking, travel, and dialogue from treating every entity as if it were an NPC-style actor. This protects the simulation model while making the CLI more understandable.

### Entity capability rules

- [x] Define the first simple capability rules for entity types.
  - NPCs are inspectable, talkable, askable, and tickable.
  - Players are inspectable and movable.
  - Locations are inspectable and may contain exits.
  - Factions are inspectable but not directly talkable or movable.
- [x] Decide whether capability checks live in a small module or private helpers.
  - Example: `Procession.EntityCapabilities`
- [x] Add helpers for common capability checks.
  - Example: `talkable?/1`
  - Example: `movable?/1`
  - Example: `location?/1`
  - Example: `tickable?/1`
- [x] Keep capability checks separate from text parsing.
- [x] Add tests for capability checks by entity type.
- [x] Document that richer capability metadata may replace simple type checks later.

### Gameplay error handling

- [x] Prevent talking to non-talkable entities.
  - Example: locations and factions.
- [x] Prevent travel to non-location entities.
- [x] Prevent movement of non-movable entities if movement helpers become generic.
- [x] Return predictable errors for unsupported capabilities.
  - Example: `{:error, :entity_not_talkable}`
  - Example: `{:error, :entity_not_movable}`
  - Example: `{:error, :entity_not_a_location}`
- [x] Add tests for talking to a location.
- [x] Add tests for talking to a faction.
- [x] Add tests for trying to travel to an NPC.
- [x] Add tests proving valid NPC dialogue still works.
- [x] Add tests proving valid travel still works.

### Tick behavior boundaries

- [x] Decide which entity types should be ticked in the current simulation.
- [x] First version should probably tick NPCs and skip player/location/faction autonomous behavior unless explicitly enabled.
- [x] Keep behavior execution owned by `Entity.tick/1`.
- [x] Avoid moving ticking rules into command parsing.
- [x] Add tests proving non-tickable entities are not treated as autonomous actors if filtering is implemented.
- [x] Keep failed behavior actions visible as structured data.

### CLI and display polish

- [x] Improve display output to prefer readable names over raw IDs where practical.
- [x] Improve local entity output in `look`.
- [x] Improve travel output after movement.
- [x] Improve error messages for unsupported capabilities.
- [x] Keep display formatting separate from simulation logic.
- [x] Add tests for display formatting improvements.

### Demo stability

- [x] Add or update a short demo transcript test.
- [x] Ensure the basic command loop still supports:
  - `look`
  - `look at Tobin`
  - `ask Tobin about road`
  - `talk to Tobin: Hello`
  - `wait`
  - `go to Briar Village`
  - `look`
  - `events for Mira`
- [x] Keep the CLI deterministic by default.
- [x] Ensure tests do not require Ollama.

### Documentation

- [x] Update `docs/USAGE.md` or demo docs with capability limits.
- [x] Document that the CLI is a thin playability layer.
- [x] Document that capability rules are intentionally simple for now.
- [x] Document deferred richer capability metadata.

### Deferred from Phase 15

- [x] Defer inventory.
- [x] Defer combat.
- [x] Defer quests.
- [x] Defer persistence.
- [x] Defer AI command parsing.
- [x] Defer large-world expansion.

---

## Phase 16: AI-Backed NPC Dialogue Through Safe Boundaries

Phase 16 brings AI closer to the playable experience.

The goal is to prove that AI improves NPC interaction while Elixir remains authoritative over state. AI dialogue should make the world feel more alive, but it should not directly mutate memory, behavior, world state, quests, or entity metadata.

### First implementation slice

- [x] Inspect the existing `Procession.AI` adapter boundary.
- [x] Inspect current `Procession.Game.talk_to/3` and `Procession.Entity.generate_response/3`.
- [x] Confirm the fake adapter remains the default test path.
- [x] Add a structured dialogue request shape if one does not already exist.
  - Example fields: `:npc`, `:player_message`, `:relevant_memories`, `:location_context`, `:world_context`.
- [x] Add a pure prompt builder function.
  - It should accept validated data.
  - It should return inspectable prompt text or structured prompt messages.
  - It should not call Ollama directly.
- [x] Add tests for prompt construction using deterministic data.
- [x] Add tests proving AI dialogue returns text only.
- [x] Add tests proving AI dialogue does not mutate memory.
- [x] Add tests proving AI dialogue does not mutate behavior metadata.
- [x] Add tests proving AI dialogue does not change NPC status/location.

### AI dialogue boundary

- [x] Add an explicit way to request Ollama-backed NPC dialogue.
- [x] Keep deterministic fake adapter as default for tests.
- [x] Restrict AI dialogue to talkable NPCs.
- [x] Reuse the existing `Procession.AI` adapter boundary.
- [x] Keep command parsing deterministic.
- [x] Do not use AI to interpret player commands in this phase.
- [x] Return generated text only.
- [x] Do not allow AI to directly mutate entity state.
- [x] Do not allow AI to create behavior metadata in this phase.
- [x] Add tests using the fake adapter.
- [x] Add manual docs for trying Ollama locally.

### Prompt context

- [x] Include NPC name, type, status, location, and traits.
- [x] Include relevant memories.
- [x] Include player message.
- [x] Include current location context if available.
- [x] Include session/world context only if it is compact and useful.
- [x] Keep prompts structured and inspectable.
- [x] Add tests for prompt construction if prompt logic grows.

### Session and command integration

- [x] Decide the first AI dialogue call shape.
  - Example: `Procession.GameSession.talk_to(session, npc_id, message, adapter: Procession.AI.Ollama)`
- [x] Keep existing deterministic dialogue behavior available.
- [x] Decide whether `Procession.Command.run/2` should remain deterministic for now.
- [x] If CLI support is added, make it explicit.
  - Example: `mix procession.play --ai`
- [x] Keep CLI deterministic by default unless intentionally changed.
- [x] Add IEx examples for AI-backed dialogue.

### AI safety and validation

- [x] Document that AI dialogue is expression, not authority.
- [x] Document that generated dialogue does not automatically become memory.
- [x] Document that generated dialogue does not automatically become behavior metadata.
- [x] Keep all state changes deterministic unless a future validated mutation path is added.
- [x] Add tests proving AI dialogue does not mutate entity state.

### Deferred from Phase 16

- [x] Defer AI autonomous planning.
- [x] Defer AI-generated behavior metadata.
- [x] Defer AI command interpretation.
- [x] Defer memory mutation from AI output.
- [x] Defer quest systems.
- [x] Defer persistence.

---

## Phase 17: Dialogue Context & Grounded AI Responses

Phase 17 creates a structured dialogue context system so AI-generated NPC dialogue is grounded in authoritative simulation data instead of ad hoc prompt text.

The goal is to make grounded NPC interaction visible through the playable shell while preserving the rule that AI dialogue is expression, not state authority.

This phase is not complete merely because the prompt contains more context. It is complete when the system can demonstrate, through tests and a real local AI run, how grounded NPC interaction behaves and where its failure modes remain.

### Context boundary

- [x] Add a plain-data dialogue context module.
  - Example: `Procession.Dialogue.Context`
- [x] Keep dialogue context construction outside the AI adapter.
- [x] Build context from authoritative Elixir state only.
- [x] Keep context data inspectable in tests.
- [x] Support context construction from both:
  - a live session process
  - already-held session state inside `GameSession`
- [x] Avoid GenServer self-calls when building context inside session callbacks.
- [x] Do not store AI output as memory in this phase.

### First context slice

- [x] Include target NPC facts.
  - ID, name, type, status, location, traits.
- [x] Include speaker facts.
  - ID, name, type.
- [x] Include current location facts.
  - ID, name, description, exits.
- [x] Include known active entities in the current session/scope.
  - ID, name, type, status, location, traits.
- [x] Include relevant target memories.
- [x] Add tests proving known entity facts appear in context.
- [x] Add tests proving context construction does not mutate entity memory.

### Prompt grounding

- [x] Update prompt builder to consume dialogue context.
- [x] Add explicit instruction not to invent facts outside provided context.
- [x] Add explicit target identity rules.
  - The target NPC must not claim to be another entity.
  - Known active entities are world facts, not speaker identity.
  - If asked about another entity, the target NPC should describe that entity while remaining itself.
- [x] Add tests proving prompt includes known entity roles and locations.
- [x] Add tests proving prompt includes uncertainty instructions.
- [x] Add tests proving prompt includes target identity instructions.
- [x] Keep prompt construction pure.

### Runtime wiring

- [x] Wire grounded context into live dialogue behind an explicit opt-in flag.
  - Example: `grounded_context: true`
- [x] Keep existing dialogue behavior unchanged when grounded context is not requested.
- [x] Ensure internal options do not leak into AI adapters.
  - Example: `:dialogue_context`, `:grounded_context`, `:memory_query`
- [x] Add tests proving the grounded path reaches the AI boundary.
- [x] Add tests proving normal dialogue still works.

### CLI-visible behavior

- [x] Add a deterministic command for grounded dialogue.
  - Example: `grounded talk to Tobin: Who is Mira?`
- [x] Add display formatting for grounded dialogue results.
  - Do not dump raw command result maps to the player.
- [x] Add an explicit AI-enabled CLI/demo entry point.
  - Example: `Procession.CLI.play_ai/2`
- [x] Keep normal CLI/demo behavior deterministic and fake-adapter safe by default.
- [x] Verify AI dialogue can answer simple grounded questions through a real local Ollama run.
  - Example: “Who is Mira?”
  - Example: “What is Mira’s occupation?”
  - Example: “Where is Mira?”
- [x] Document that small local models may still hallucinate or confuse speaker identity.
- [x] Add a Phase 17 grounded dialogue acceptance note.
  - Example: `docs/PHASE_17_GROUNDED_DIALOGUE_ACCEPTANCE.md`
- [x] Record at least one real local Ollama run.
- [x] Document known grounded dialogue failure modes.
- [x] Carry unresolved consistency/quality failures into Phase 18.

### Human acceptance script

Run the AI-enabled demo with the local model and manually compare normal dialogue with grounded dialogue.

Recommended script:

- [x] `talk to Tobin: Who is Mira?`
- [x] `grounded talk to Tobin: Who is Mira?`
- [x] `grounded talk to Tobin: Where is Mira?`
- [x] `grounded talk to Tobin: What is Mira's job?`
- [x] `grounded talk to Mira: Who is Tobin?`
- [x] `grounded talk to Tobin: Who is Elandra?`

Acceptance notes:

- [x] Tobin should not claim to be Mira.
- [x] Mira should not claim to be Tobin.
- [x] Known facts should be used when present.
- [x] Unknown facts should produce uncertainty instead of invented lore.
- [x] Any remaining failure modes should be documented for Phase 18.

### Observed post-augment failure pattern

After identity hardening, scoped prompt sections, and grounded dialogue display formatting, the local model showed improved structure but still failed bounded NPC interaction.

Observed failure type:

- Context overload / field bleed.
  - Tobin’s nervous temperament bled into player behavior.
  - Mira’s `innkeeper` role led to inferred services, hospitality, and inn activity.
  - The crossroads description led to inferred bustle and travel activity.
  - Unknown entity handling sometimes started with uncertainty, then invented unsupported lore.

Conclusion:

Phase 17 successfully made grounded NPC dialogue visible, testable, and diagnosable. Remaining consistency and quality failures belong to Phase 18, where `npc_interaction` becomes a task-specific AI skill with validation, evals, curated training data, and a first local training experiment.

### Deferred from Phase 17

- [x] Defer storing AI dialogue as memory.
- [x] Defer AI-generated facts becoming world truth.
- [x] Defer long-term conversation memory.
- [x] Defer validated rumor/thread mutation.
- [x] Defer NPC-specific knowledge limits beyond active scope.
- [x] Defer model training.
- [x] Defer separate AI skills beyond `npc_interaction`.

---