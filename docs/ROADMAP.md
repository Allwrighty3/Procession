# Roadmap

The detailed phase checklists include both completion blockers and future refinement ideas. The formal criteria for completing each section is listed at the bottom.

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
- [ ] Add validation for incoming messages.
- [x] Decide what should happen when a message is sent to an entity that does not exist.
- [x] Add tests for failed message delivery.
- [ ] Add entity-to-entity interaction examples.

#### Entity state

- [ ] Add a cleaner state update API for common changes.
  - [x] Status updates: `Entity.set_status/2`
  - [x] Location updates: `Entity.move_to/2`
  - [x] Trait updates: `Entity.set_trait/3`
  - [x] Entity metadata updates: `Entity.set_metadata/3`
  - [ ] Relationship updates
- [x] Add tests for updating traits.
- [x] Add tests for updating entity metadata.
- [ ] Decide which fields belong directly on an entity and which should become separate systems later.

#### Supervision and fault tolerance

- [x] Add tests proving entity processes restart correctly after crashes.
- [ ] Decide whether restarted entities should keep state, reset state, or reload state.
- [x] Add a basic crash/recovery test for the `DynamicSupervisor`.
- [ ] Decide whether persistence is needed before Phase 3 or can wait.

#### Developer ergonomics

- [x] Add convenience functions for spawning common entity types.
  - Example: `start_npc/2`, `start_location/2`, `start_faction/2`.
- [x] Add documentation examples for starting entities and sending messages.
- [x] Add basic `iex` usage examples to the README.

---

### Phase 2: Hierarchical Memory System

Phase 2 is complete by the criteria below. The remaining items here are backlog/refinement tasks.

#### Memory structure

- [x] Finalize the memory entry schema.
  - Current fields include `:content`, `:type`, `:importance`, `:timestamp`, and `:from`.
- [x] Decide whether memory entries should include an ID.
- [x] Add optional metadata fields.
  - Example: `:source`, `:tags`, `:location`, `:related_entities`.
- [x] Add tests for memory entries with metadata.
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
- [ ] Defer full persistence unless needed before AI integration.

#### Debugging and inspection

- [x] Add a simple way to inspect memory counts per entity.
  - Example: `%{short: 10, medium: 50, long: 200}`.
- [x] Add an entity API like `Entity.memory_summary(id)`.
- [x] Add tests for memory summary output.
- [x] Add README examples showing memory promotion and recall.

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
- [x] Add tests for the public AI API using a deterministic fake adapter.

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
- [x] Add tests that do not require Ollama to be running.
- [x] Add optional/manual test instructions for testing against a real local Ollama server.

#### Prompt structure

- [x] Define a small prompt-building helper.
- [x] Start with plain strings before introducing complex prompt structs.
- [x] Add a basic system/context convention.
  - Example: world context, entity state, relevant memories, player input.
- [x] Keep prompts request-based.
- [x] Do not create persistent chat threads per entity.

#### Entity integration preparation

- [x] Decide the first entity AI use case.
  - Example: generate a short NPC response.
- [x] Add an explicit entity-facing function only after the AI boundary works.
  - Example: `Entity.generate_response(id, player_message)`.
- [x] Include only structured entity state and selected memories in the request.
- [x] Keep AI output as data returned to the caller first.
- [x] Do not automatically mutate entity state from AI output in the first version.
- [x] Add tests proving entity AI integration can be exercised with the fake adapter.

#### Memory integration preparation

- [x] Decide how many memories should be included in an AI request.
  - Example: recent 5 plus important memories.
- [x] Add a helper for selecting AI-relevant memories.
- [x] Keep memory selection deterministic before using AI summarization.
- [x] Defer LLM-generated memory summaries until basic generation works.
- [x] Add tests for memory selection before connecting it to Ollama.

#### Developer ergonomics

- [x] Add README examples for calling the AI boundary from IEx.
- [x] Add README instructions for installing and running Ollama locally.
- [x] Document how to pull the chosen local model.
- [x] Document what happens if Ollama is not running.
- [x] Keep all Phase 3 examples small and copy-pasteable.

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
- [x] Add tests for expected blueprint shape.

#### Deterministic starter generator

- [x] Add a deterministic generator that does not require Ollama.
- [x] Use this deterministic generator for tests.
- [x] Generate a tiny default world from a prompt.
  - Example: 3 locations, 3 NPCs, 1 faction.
- [x] Use string IDs compatible with the existing ID conventions.
  - Example: `loc_`, `npc_`, `faction_`.
- [x] Avoid random behavior in tests unless seeded.
- [x] Add tests proving generation is repeatable.

#### AI-assisted generation preparation

- [x] Add a generator prompt helper.
- [x] Keep generator prompts plain strings at first.
- [x] Include clear output expectations in the prompt.
- [x] Ask the AI for small structured output only.
- [x] Do not rely on AI-generated output until deterministic generation works.
- [x] Add tests for prompt construction without calling Ollama.

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
- [x] Add tests for valid and invalid blueprints.

#### Spawning generated worlds

- [x] Add a separate function for spawning a blueprint into live entity processes.
  - Example: `Procession.Generator.spawn_world(world_blueprint)`
- [x] Keep generation and spawning separate.
- [x] Start generated locations through `EntitySupervisor`.
- [x] Start generated NPCs through `EntitySupervisor`.
- [x] Start generated factions through `EntitySupervisor`.
- [x] Attach starter memories only after entities are created.
- [x] Return a summary of created entities.
- [x] Add tests proving entities are created from a blueprint.

#### Starter memories and relationships

- [x] Decide how generated memories should be attached to NPCs.
- [x] Use existing entity message/memory behavior where possible.
- [x] Add starter rumors, observations, or faction opinions as memories.
- [x] Represent relationships in metadata first.
- [x] Defer a full relationship system unless needed.
- [x] Add tests proving generated NPCs receive starter memories.

#### Developer ergonomics

- [x] Add README examples for deterministic world generation.
- [x] Add README examples for spawning a generated world.
- [x] Add README examples for AI-assisted generation if available.
- [x] Keep examples small enough to run in IEx.
- [x] Document that generation returns a blueprint before spawning entities.
- [x] Document that generated worlds are local and zero-budget.

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
- [x] Start with plain function calls before adding LiveView or UI behavior.
- [x] Standardize return values.
  - Example: `{:ok, result}` or `{:error, reason}`
- [x] Add tests for the public gameplay API.
- [x] Avoid creating a supervised gameplay process unless stateful orchestration is clearly needed.

#### World inspection

- [x] Add a basic function for inspecting a live entity.
  - Example: `Procession.Game.look(entity_id)`
- [x] Return a player-friendly summary of entity state.
  - Example fields: `:id`, `:name`, `:type`, `:location`, `:status`, `:traits`, `:relationships`, `:memory_summary`.
- [x] Handle missing entities predictably.
  - Example: `{:error, :entity_not_found}`
- [x] Add tests for inspecting NPCs, locations, and factions.
- [x] Add tests for missing entity lookup.
- [x] Keep the first inspection result as plain data, not formatted prose.

#### Generated world gameplay setup

- [x] Add a helper for creating a playable test world.
  - Example: `Procession.Game.new_game(prompt)`
- [x] Use the deterministic generator first.
- [x] Validate the generated blueprint before spawning.
- [x] Spawn the generated world through `Procession.Generator.spawn_world/1`.
- [x] Return a summary that includes the world name and created entity IDs.
- [x] Do not use AI generation for the first playable setup path.
- [x] Add tests proving a new playable world can be created from a prompt.

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
- [x] Add tests for valid and invalid player actions.

#### Movement

- [ ] Decide how locations are connected.
  - Start with simple relationship or metadata links.
- [ ] Add a minimal movement function.
  - Example: `Procession.Game.move(entity_id, location_id)`
- [ ] Use existing `Entity.move_to/2` when possible.
- [ ] Validate that the destination location exists.
- [ ] Defer maps, pathfinding, and travel rules until later.
- [ ] Add tests for successful and failed movement.

#### Dialogue

- [x] Add a simple player-to-NPC dialogue helper.
  - Example: `Procession.Game.talk_to(npc_id, player_message, opts \\ [])`
- [x] Use `Entity.generate_response/3` for optional AI-backed dialogue.
- [x] Support deterministic fake-adapter dialogue in tests.
- [x] Keep generated dialogue as returned data first.
- [x] Do not automatically mutate NPC state from AI dialogue yet.
- [x] Add tests proving dialogue can be requested safely.

#### Memory-driven interaction

- [x] Add a simple helper for recalling what an NPC knows.
  - Example: `Procession.Game.ask_about(npc_id, topic)`
- [x] Use existing entity recall helpers.
- [x] Keep recall deterministic before adding AI summarization.
- [x] Return matching memories as data.
- [x] Add tests for asking about known and unknown topics.

#### Gameplay loop preparation

- [x] Define the first tiny gameplay loop.
  - Example: create world, inspect NPC, talk to NPC, inspect memory.
- [x] Keep the loop runnable from IEx.
- [x] Add README examples for the first playable loop.
- [x] Avoid building command parsing until the function-based loop works.
- [x] Avoid building Phoenix LiveView until core gameplay APIs feel stable.

#### Developer ergonomics

- [x] Add README examples for `Procession.Game.look/1`.
- [x] Add README examples for creating a playable deterministic world.
- [x] Add README examples for the first player action.
- [x] Keep all examples copy-pasteable in IEx.
- [x] Document which Phase 5 features are deterministic and which optionally use AI.
- [x] Document cleanup steps for generated test worlds.

#### Autonomous world activity

Autonomous world activity should support the core Procession vision: entities are lightweight OTP actors that can act from their own state, memory, traits, metadata, and relationships.

The deterministic starter world may include named example NPCs for tests and IEx demos, but the autonomous behavior system must not depend on those names. Future AI-generated worlds may not include Mira, Tobin, Elin, or any specific hardcoded entity.

The intended model is:

- The world generator creates entities.
- Generated entities may include behavior metadata.
- Entities own their possible behaviors.
- `Procession.Game.tick_world/0` coordinates a world tick.
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
- [x] Keep `Procession.Game.tick_world/0` as a coordinator, not the source of behavior.
- [x] Make `Game.tick_world/0` discover live entities instead of assuming specific IDs.
- [x] Return a summary of entity-driven actions from each tick.
- [x] Keep the first version manually triggered from IEx.
- [x] Defer timers, schedulers, background loops, complex NPC goals, and AI-driven autonomy.
- [x] Add tests proving an entity can act from behavior metadata without direct player action.
- [x] Add tests proving `Game.tick_world/0` coordinates entity ticks rather than selecting hardcoded events.

#### Future refinements

- [ ] Add a command parser for text commands.
  - Example: `"look at Mira"` or `"talk to Mira"`
- [ ] Add quest generation.
- [ ] Add inventory.
- [ ] Add items and item ownership.
- [ ] Add location exits and travel restrictions.
- [ ] Add faction reputation.
- [ ] Add NPC goals.
- [ ] Add scheduled world events.
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
- [x] Add tests for valid behavior metadata.
- [x] Add tests for missing required behavior fields.
- [x] Add tests for unsupported behavior actions.
- [x] Add tests for unsupported behavior triggers.

#### Blueprint integration

- [x] Validate NPC behavior metadata during blueprint validation.
- [x] Keep behavior validation inside generator validation small and explicit.
- [x] Ensure invalid generated behavior metadata prevents unsafe world spawning.
- [x] Preserve valid behavior metadata when spawning generated NPCs.
- [ ] Keep deterministic generator output using one or two sample behaviors only.
- [ ] Do not require every generated NPC to have behavior metadata.
- [x] Add tests proving blueprints with valid behavior metadata pass validation.
- [x] Add tests proving blueprints with invalid behavior metadata fail validation.
- [x] Add tests proving NPCs without behaviors still spawn normally.
- [x] Add tests proving behavior metadata survives spawning into live entity state.

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
- [x] Add tests proving `:send_message` behavior still works after routing through the behavior module.
- [x] Add tests proving behavior execution does not depend on fixture NPC names.

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
- [x] Add tests proving entity behavior can update entity state.
- [x] Add tests proving invalid status behavior is rejected predictably.
- [x] Keep this action deterministic and local.

#### AI boundary preparation

- [x] Document that AI-generated behavior metadata is untrusted.
- [x] Document that AI output must be validated before spawning or execution.
- [x] Keep behavior execution limited to a safe action vocabulary.
- [x] Do not allow AI-generated behavior to call arbitrary functions.
- [x] Do not allow AI-generated behavior to create atoms dynamically.
- [x] Keep AI-generated behavior parsing out of Phase 6 unless the schema is stable.
- [x] Defer AI-driven behavior selection until deterministic schema validation is solid.
- [x] Defer goals, planning, utility scoring, and personality-driven autonomy.

---

### Phase 7: World Simulation Clock & Scheduling

Phase 7 introduces a controlled world simulation cadence.

The goal is to move from manually calling `Procession.Game.tick_world/0` toward a simple, testable simulation loop without turning the project into a runaway background-agent circus.

Scheduling should coordinate existing entity ticks; it should not replace entity-owned behavior.

#### Clock boundary

- [x] Add a dedicated world clock module.
  - Example: `Procession.WorldClock`
- [x] Keep the clock separate from `Procession.Game`.
- [x] Keep `Procession.Game.tick_world/0` usable as a direct manual tick.
- [x] Make the clock call the existing gameplay/world tick boundary.
- [x] Do not duplicate entity tick logic inside the clock.
- [x] Do not move behavior execution into the clock.
- [x] Document the difference between manual ticks and scheduled ticks.

#### Manual clock process

- [x] Start with a manually controlled GenServer.
  - Example: `Procession.WorldClock.start_link/1`
- [x] Add a public API for triggering one tick through the clock.
  - Example: `Procession.WorldClock.tick(clock_pid)`
- [x] Store the latest tick summary in clock state.
- [x] Expose the latest tick summary.
  - Example: `Procession.WorldClock.last_tick(clock_pid)`
- [x] Track the total number of ticks coordinated by the clock.
- [x] Add tests for starting the clock.
- [x] Add tests for manually triggering a clock tick.
- [x] Add tests proving the clock delegates to `Game.tick_world/0`.
- [x] Add tests proving tick summaries are stored and inspectable.

#### Supervision

- [x] Add the world clock to supervision only after the manual clock API works.
- [x] Decide whether the clock is always started or started only for a game session.
- [x] Prevent duplicate world clocks from running accidentally.
- [x] Name/register the clock only if needed.
- [x] Keep failure behavior simple and idiomatic OTP.
- [x] Add tests for supervised clock startup.
- [x] Add tests for predictable restart behavior if supervision is added.
- [x] Avoid adding a full game-session process in Phase 7 unless clearly needed.

#### Optional interval ticking

- [x] Add optional interval-based ticking.
  - Example: `interval_ms: 1_000`
- [x] Keep interval ticking disabled by default.
- [x] Add a way to start interval ticking.
- [x] Add a way to stop interval ticking.
- [x] Ensure scheduled ticks do not overlap.
- [x] Ensure interval ticking can be tested deterministically.
- [x] Keep intervals configurable.
- [x] Add tests proving scheduled ticks occur when enabled.
- [x] Add tests proving scheduled ticks stop when disabled.
- [x] Add tests proving scheduled ticks do not require Ollama.

#### Tick result handling

- [x] Keep tick summaries as plain data.
- [x] Include total entities ticked.
- [x] Include successful entity actions.
- [x] Include failed entity actions.
- [x] Include clock tick count.
- [x] Include monotonic clock tick number.
- [x] Keep recent summaries inspectable from IEx.
- [x] Avoid persistence in Phase 7.
- [x] Avoid database/storage decisions in Phase 7.
- [x] Add tests for successful tick summaries.
- [x] Add tests for failed entity action summaries.
- [x] Add tests proving one failed entity action does not crash the whole clock.

#### Failure isolation

- [x] Make sure one entity tick failure does not crash the full world tick.
- [x] Collect failed tick results as data.
- [x] Keep failures visible in the tick summary.
- [x] Avoid swallowing errors silently.
- [x] Add tests for missing target entities during scheduled ticks.
- [x] Add tests for unsupported behavior during scheduled ticks.
- [x] Add tests proving the clock remains alive after a failed entity action.
- [x] Keep clock behavior boring and reliable. Boring is allowed here. Heroics are how schedulers become gremlins.

#### Documentation and IEx demos

- [x] Add README examples for manual world ticking.
- [x] Add README examples for starting a clock.
- [x] Add README examples for triggering a tick through the clock.
- [x] Add README examples for inspecting the last tick summary.
- [x] Add README examples for optional interval ticking if implemented.
- [x] Document how to stop scheduled ticking.
- [x] Document that scheduled ticking still uses entity-owned behavior.
- [x] Document that the clock does not own story logic.

#### Deferred from Phase 7

- [x] Defer persistence.
- [x] Defer Phoenix LiveView.
- [x] Defer complex calendars/time systems.
- [x] Defer faction-scale simulation.
- [x] Defer quest progression.
- [x] Defer combat/conflict systems.
- [x] Defer AI-driven autonomous planning.
- [x] Defer multi-world or multi-session support unless unavoidable.

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
* [x] Do not move entity behavior execution into the session.
* [x] Do not move generation logic into the session.
* [x] Add tests for starting a session process.

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
* [x] Add tests for initial session state.
* [x] Add tests for session summary output.

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
* [x] Add tests proving a session can create a deterministic game.
* [x] Add tests proving generated entities are live after session game creation.
* [x] Add tests proving the session tracks all generated entity IDs.

#### Active entity ownership

* [x] Add an API for listing active session entities.

  * Example: `Procession.GameSession.active_entities(session)`
* [x] Add an API for checking whether an entity belongs to a session.

  * Example: `Procession.GameSession.owns_entity?(session, entity_id)`
* [x] Keep ownership as plain string IDs.
* [x] Do not create atoms from generated IDs.
* [x] Avoid relying on fixture-specific NPC names in session logic.
* [x] Add tests for active entity listing.
* [x] Add tests for ownership checks.
* [x] Add tests proving unknown entities are not owned by the session.

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
* [x] Add tests proving cleanup stops session-owned entities.
* [x] Add tests proving cleanup does not crash if an owned entity is already stopped.
* [x] Add tests proving cleanup is idempotent.
* [x] Add tests proving the session process remains alive after cleanup.

#### Session and clock relationship

* [x] Decide how sessions relate to the existing supervised world clock.
* [x] Keep the first version simple.

  * Recommended first version: session does not own a private clock.
* [x] Document that `WorldClock` still ticks all live entities for now.
* [x] Defer session-scoped ticking until after ownership is stable.
* [x] Add tests proving existing `WorldClock` behavior still works with session-created entities.
* [x] Do not add per-session clocks yet unless clearly needed.

#### Documentation and IEx demos

* [x] Add README or USAGE examples for starting a game session.
* [x] Add examples for creating a generated game through a session.
* [x] Add examples for inspecting a session summary.
* [x] Add examples for listing active session entities.
* [x] Add examples for cleaning up a session.
* [x] Document that sessions own live entity IDs but do not yet implement persistence.
* [x] Document that inactive blueprint scopes are still future work.

#### Deferred from Phase 8

* [x] Defer command parsing.
* [x] Defer player entity creation.
* [x] Defer location travel.
* [x] Defer scoped ticking.
* [x] Defer persistence.
* [x] Defer Phoenix LiveView.
* [x] Defer lazy world expansion.
* [x] Defer multi-session persistence or save/load behavior.

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
* [x] Add tests for successful session-aware look.
* [x] Add tests for successful session-aware memory queries.
* [x] Add tests for successful session-aware dialogue.
* [x] Add tests for missing or non-owned target entities.

#### Session-aware ticking

* [x] Add a session tick API.

  * Example: `Procession.GameSession.tick(session)`
* [x] First version may delegate to `Procession.Game.tick_world/0`.
* [x] Document that session tick is not yet scoped to session-owned entities unless implemented.
* [x] Return the tick summary as plain data.
* [x] Store the latest tick summary in session state if useful.
* [x] Add tests proving session tick coordinates world behavior.
* [x] Add tests proving failed behavior actions are still returned as data.
* [x] Do not duplicate entity tick logic inside `GameSession`.

#### Session event inspection

* [x] Add session-aware recent event inspection.

  * Example: `Procession.GameSession.recent_events(session, entity_id)`
* [x] Require the entity to belong to the session.
* [x] Delegate to existing event/memory APIs where possible.
* [x] Return predictable errors for non-session entities.
* [x] Add tests for recent events through the session boundary.
* [x] Add tests for invalid or outside-session event requests.

#### Session action API

* [x] Add a generic session action helper if useful.

  * Example: `Procession.GameSession.perform(session, :look, entity_id: "npc_mira")`
* [x] Keep actions as atoms and keyword options.
* [x] Do not parse text commands yet.
* [x] Delegate existing player actions to session-aware helpers.
* [x] Return predictable errors for invalid actions.
* [x] Add tests for supported session actions.
* [x] Add tests for unsupported session actions.
* [x] Add tests for missing action arguments.

#### Session summary improvements

* [x] Include active entity counts in session summary.
* [x] Include world name or generated game name in session summary.
* [x] Include session status.
* [x] Include last tick summary if stored.
* [x] Keep summary as plain data.
* [x] Add tests for useful session summary output.

#### Documentation and IEx demos

* [x] Add examples for looking at entities through a session.
* [x] Add examples for asking NPCs about memories through a session.
* [x] Add examples for dialogue through a session.
* [x] Add examples for ticking through a session.
* [x] Add examples for inspecting recent events through a session.
* [x] Document that session-aware APIs protect against interacting with unrelated live entities.

#### Deferred from Phase 9

* [x] Defer command parsing.
* [x] Defer player entity.
* [x] Defer location-relative commands.
* [x] Defer scoped ticking unless it becomes trivial.
* [x] Defer UI.
* [x] Defer persistence.

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
* [x] Add tests for starting a player entity.
* [x] Add tests proving the session owns the player entity.

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
* [ ] Add tests proving non-NPC entities cannot be talked to.
* [ ] Add tests proving non-tickable entities are not treated as autonomous actors if ticking rules are updated.
* [ ] Document that richer capability metadata may replace simple type checks later.


#### Session player ownership

* [x] Add player ID to session state.
* [x] Add a session API for fetching the current player.

  * Example: `Procession.GameSession.player(session)`
* [x] Add a session API for fetching player location.

  * Example: `Procession.GameSession.player_location(session)`
* [x] Include the player in session cleanup.
* [x] Add tests proving cleanup stops the player entity.
* [x] Add tests for player summary output.

#### Location context

* [x] Add a helper for looking at the player's current location.

  * Example: `Procession.GameSession.look(session)`
* [x] Keep `look(session, entity_id)` available for specific targets.
* [x] Return current location summary when no target is provided.
* [x] Include known NPCs or entities at the current location if simple.
* [x] Add tests for location-relative look.
* [x] Add tests for looking at a specific entity from the session.
* [x] Add predictable errors when the player has no valid location.

#### Local entity discovery

* [x] Add a helper for listing entities at the player's current location.

  * Example: `Procession.GameSession.local_entities(session)`
* [x] Use live entity state to determine locations.
* [x] Limit results to session-owned entities.
* [x] Add tests proving only session-owned entities are listed.
* [x] Add tests proving entities in other locations are excluded.
* [x] Add tests proving unknown global entities are excluded.

#### Player memory preparation

* [x] Decide whether player actions should create memories immediately.
* [x] First version may avoid automatic player memory.
* [ ] Add a basic player memory example only if useful.
* [x] Defer richer journaling or quest logs.
* [x] Document the decision.

#### Documentation and IEx demos

* [x] Add examples for creating a session with a player.
* [x] Add examples for checking player location.
* [x] Add examples for `look` using player location context.
* [x] Add examples for listing local entities.
* [x] Document that player inventory, quests, and stats are deferred.

#### Deferred from Phase 10

* [x] Defer inventory.
* [x] Defer stats and character creation.
* [x] Defer combat.
* [x] Defer quests.
* [x] Defer player persistence.
* [x] Defer complex movement rules.

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
* [x] Add tests for invalid command input.
* [x] Add tests for unknown commands.

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
* [x] Add tests for each supported command.
* [x] Add tests for missing targets or malformed command text.

#### Entity name resolution

* [x] Add simple entity name lookup within a session.
* [x] Match exact entity IDs first.
* [x] Match entity names second.
* [x] Limit lookup to session-owned entities.
* [x] Return predictable errors for ambiguous names.

  * Example: `{:error, {:ambiguous_entity, matches}}`
* [x] Return predictable errors for unknown names.

  * Example: `{:error, :entity_not_found}`
* [x] Add tests for ID lookup.
* [x] Add tests for name lookup.
* [x] Add tests for unknown and ambiguous names.

#### Command result formatting

* [x] Return command results as plain data first.
* [x] Avoid human-readable prose formatting until command data is stable.
* [x] Use consistent result shapes.

  * Example: `{:ok, %{command: :look, result: summary}}`
* [x] Add tests for command result shapes.
* [x] Defer rich text rendering.

#### Documentation and IEx demos

* [x] Add IEx examples for command parsing.
* [x] Show a tiny command-based play loop.
* [x] Document supported commands.
* [x] Document that command parsing is deterministic and local.
* [x] Document that AI command interpretation is deferred.

#### Deferred from Phase 11

* [x] Defer fuzzy command parsing.
* [x] Defer natural language AI command parsing.
* [x] Defer CLI loop.
* [x] Defer Phoenix LiveView.
* [x] Defer command history.
* [x] Defer aliases and shortcuts unless trivial.

---

### Phase 12: Basic Travel & Active Scope Preparation

Phase 12 adds simple location movement and prepares for active scopes.

The goal is not full maps or pathfinding. The goal is to let the player move between known locations in the starter world using simple deterministic exits.

#### Location exits

* [ ] Decide how location exits are represented.

  * Recommended first version: location metadata.
  * Example: `metadata.exits`
* [ ] Define a simple exit shape.

  * Example: `%{to: "loc_silent_mine", label: "mine road"}`
* [ ] Add deterministic exits to the starter generated world.
* [ ] Validate that exit destinations reference known locations.
* [ ] Do not add pathfinding yet.
* [ ] Do not add travel time yet unless trivial.
* [ ] Add tests for valid exits.
* [ ] Add tests for invalid exit destinations.

#### Player movement

* [ ] Add a session-aware movement API.

  * Example: `Procession.GameSession.travel(session, destination)`
* [ ] Require the player entity to exist.
* [ ] Require the destination to be reachable from the current location.
* [ ] Update player location through existing entity state APIs.
* [ ] Return a plain movement summary.

  * Example: `%{from: "loc_a", to: "loc_b"}`
* [ ] Return predictable errors for unreachable destinations.
* [ ] Return predictable errors for unknown destinations.
* [ ] Add tests for successful movement.
* [ ] Add tests for failed movement.

#### Travel commands

* [ ] Add command support for travel.

  * Example: `go to Silent Mine`
  * Example: `travel to Crossroads`
* [ ] Resolve destination by location ID or name.
* [ ] Require the destination to be reachable.
* [ ] Add tests for successful travel commands.
* [ ] Add tests for invalid travel commands.

#### Location-relative gameplay

* [ ] Update `look` to show the player's current location after travel.
* [ ] Update local entity listing after travel.
* [ ] Ensure entities from other locations are not shown as local.
* [ ] Add tests proving local context changes after travel.
* [ ] Add tests for looking after movement.

#### Active scope preparation

* [ ] Add a simple active scope concept to session state if useful.

  * Example: `active_scope: "scope_starter_area"`
* [ ] Keep active scope as metadata or plain data first.
* [ ] Do not implement lazy spawning yet.
* [ ] Document that all starter locations are still live in this phase.
* [ ] Add tests for active scope summary if implemented.

#### Documentation and IEx demos

* [ ] Add examples for location exits.
* [ ] Add examples for player travel.
* [ ] Add examples for command-based travel.
* [ ] Add examples showing `look` before and after travel.
* [ ] Document that maps, pathfinding, travel time, and large-world scope loading are deferred.

#### Deferred from Phase 12

* [ ] Defer pathfinding.
* [ ] Defer travel time.
* [ ] Defer random encounters.
* [ ] Defer locked exits.
* [ ] Defer region-to-region travel.
* [ ] Defer lazy spawning and hydration.
* [ ] Defer large-scale maps.

---

### Phase 13: First Playable Vertical Slice

Phase 13 packages the existing systems into a tiny playable loop.

The goal is to make Procession playable for 5-10 minutes through deterministic commands in IEx. This is not the final UI, not a full game, and not a content-complete experience. It is the first cohesive prototype.

#### Vertical slice setup

* [ ] Add a helper for starting the first playable prototype.

  * Example: `Procession.GameSession.start_demo/1`
  * Or keep setup as documented IEx commands if a helper is premature.
* [ ] Create a deterministic game session.
* [ ] Create a player entity.
* [ ] Spawn the starter world.
* [ ] Track active session entities.
* [ ] Ensure player starts at a valid location.
* [ ] Return a useful startup summary.
* [ ] Add tests for vertical slice setup.

#### Minimum playable command loop

* [ ] Ensure the player can run `look`.
* [ ] Ensure the player can run `look at <npc>`.
* [ ] Ensure the player can run `ask <npc> about <topic>`.
* [ ] Ensure the player can run `talk to <npc>: <message>`.
* [ ] Ensure the player can run `wait`.
* [ ] Ensure the player can inspect recent events.
* [ ] Ensure the player can travel between starter locations.
* [ ] Add tests for a multi-command play sequence.

#### World reactivity

* [ ] Ensure `wait` triggers world ticking.
* [ ] Ensure NPC behavior can create visible events or memories.
* [ ] Ensure failed NPC behavior remains visible as structured data.
* [ ] Ensure the clock is not required for manual play.
* [ ] Optionally allow interval ticking during the demo.
* [ ] Add tests proving playerless behavior affects later player inspection.

#### Demo content expectations

* [ ] Keep demo content deterministic.
* [ ] Use the current starter world unless a small content update is needed.
* [ ] Ensure at least one NPC has useful memory to ask about.
* [ ] Ensure at least one NPC behavior creates a visible change.
* [ ] Ensure at least two locations are reachable.
* [ ] Avoid adding a quest system yet.
* [ ] Avoid adding inventory yet.
* [ ] Avoid adding combat yet.

#### Result shaping

* [ ] Decide whether command results should remain raw data or include simple display text.
* [ ] If display text is added, keep it separate from core gameplay state.
* [ ] Add small formatting helpers only if needed for playability.
* [ ] Do not let formatting own gameplay logic.
* [ ] Add tests for any display formatting helpers.

#### Documentation and demo script

* [ ] Add a documented 5-minute IEx demo script.
* [ ] Include setup commands.
* [ ] Include at least one `look`.
* [ ] Include at least one NPC interaction.
* [ ] Include at least one `wait`.
* [ ] Include at least one travel command.
* [ ] Include cleanup instructions.
* [ ] Document what is deterministic and what is optional AI.

#### Deferred from Phase 13

* [ ] Defer full CLI.
* [ ] Defer Phoenix LiveView.
* [ ] Defer inventory.
* [ ] Defer quests.
* [ ] Defer combat.
* [ ] Defer save/load.
* [ ] Defer large-world expansion.
* [ ] Defer AI command parsing.

---

### Phase 14: Tiny Local CLI Loop

Phase 14 adds a simple local terminal play loop.

The goal is to make the vertical slice playable without manually calling IEx functions. This should remain local, zero-budget, and small.

#### CLI entry point

* [ ] Decide the simplest CLI entry point.

  * Example: custom Mix task `mix procession.play`
* [ ] Add a Mix task for starting the playable demo.

  * Example: `Mix.Tasks.Procession.Play`
* [ ] Start or reuse a game session.
* [ ] Create the deterministic starter world.
* [ ] Create the player entity.
* [ ] Print a short intro.
* [ ] Accept typed commands from stdin.
* [ ] Add tests for CLI setup where practical.
* [ ] Keep command parsing delegated to `Procession.Command`.

#### CLI command loop

* [ ] Read player input line by line.
* [ ] Send commands to the deterministic command parser.
* [ ] Print command results in a readable format.
* [ ] Support `help`.
* [ ] Support `quit`.
* [ ] Keep the loop local and synchronous.
* [ ] Do not require Phoenix.
* [ ] Do not require Ollama.
* [ ] Do not require a database.

#### Simple output formatting

* [ ] Add basic display formatting for look results.
* [ ] Add basic display formatting for memory/event results.
* [ ] Add basic display formatting for travel results.
* [ ] Add basic display formatting for errors.
* [ ] Keep formatting separate from simulation logic.
* [ ] Add tests for formatting helpers if they are separate modules.

#### Safety and cleanup

* [ ] Stop interval ticking when quitting if it was started.
* [ ] Clean up session-owned entities on quit.
* [ ] Handle invalid commands without crashing the loop.
* [ ] Handle Ctrl+C as gracefully as practical.
* [ ] Document cleanup behavior.

#### Documentation

* [ ] Add instructions for running the CLI prototype.

  * Example: `mix procession.play`
* [ ] Document supported commands.
* [ ] Document that the CLI is a prototype.
* [ ] Document that the simulation core remains Elixir/OTP-first.
* [ ] Document that Phoenix LiveView is still deferred.

#### Deferred from Phase 14

* [ ] Defer Phoenix LiveView.
* [ ] Defer save/load.
* [ ] Defer multiple concurrent sessions in the CLI.
* [ ] Defer rich UI.
* [ ] Defer combat.
* [ ] Defer quest tracking.
* [ ] Defer AI command interpretation.

---

## Phase Completion Criteria

### Phase 1 is complete when:

- [x] Entities can be started, stopped, looked up, and listed.
- [x] Entities can send structured messages to each other.
- [x] Message delivery failure is handled predictably.
- [x] Entity status and location can be updated through clear public APIs.
- [x] Supervision behavior is tested.
- [x] Basic usage is documented in the README.

### Phase 2 is complete when:

- [x] Memories use a consistent structure.
- [x] Short, medium, and long memory layers are tested.
- [x] Promotion rules are clear and tested.
- [x] Entity APIs exist for common recall operations.
- [x] Search supports content and metadata-based recall.
- [x] Memory ordering is intentional and tested.
- [x] Memory inspection/debug helpers exist.
- [x] README examples show how entity memory works.

### Phase 3 is complete when:

- [x] A public AI boundary exists outside the entity and memory modules.
- [x] AI calls use a small adapter behavior.
- [x] A fake adapter supports deterministic tests.
- [x] An Ollama adapter can make a local request to a locally running model.
- [x] Ollama connection/model errors are handled predictably.
- [x] At least one simple IEx example can generate local AI text.
- [x] Entities can optionally request AI-generated output through a controlled public API.
- [x] Entity AI requests use structured state and selected memories.
- [x] Tests do not require Ollama to be installed or running.
- [x] README documentation explains local setup and basic usage.

### Phase 4 is complete when:

- [x] A public generator boundary exists outside the entity and AI modules.
- [x] A deterministic generator can create a small world blueprint from a prompt.
- [x] Generated blueprints include locations, NPCs, factions, relationships, and starter memories.
- [x] Blueprint validation catches missing fields, duplicate IDs, and broken references.
- [x] A generated blueprint can be spawned into live entity processes.
- [x] Generated entities use the existing supervisor and registry.
- [x] Starter memories can be attached to generated NPCs.
- [x] AI-assisted generation is optional and uses the existing AI boundary.
- [x] Tests do not require Ollama to be installed or running.
- [x] README documentation explains deterministic generation, spawning, and optional local AI generation.

### Phase 5 is complete when:

- [x] A public gameplay boundary exists outside the entity, memory, generator, and AI modules.
- [x] The player can inspect live entities through a simple gameplay API.
- [x] Missing or invalid gameplay targets return predictable errors instead of crashing.
- [x] A deterministic playable world can be created from a prompt.
- [x] Generated worlds can be inspected through gameplay functions after spawning.
- [x] At least one simple player action works through a public gameplay API.
- [x] Player-to-NPC dialogue can be requested safely.
- [x] Dialogue tests do not require Ollama to be installed or running.
- [x] NPC memories can be queried through a gameplay-facing helper.
- [x] The first tiny gameplay loop is runnable from IEx.
- [x] README documentation explains the first playable loop.
- [x] Tests cover the core gameplay boundary and first player actions.
- [x] A manually triggered world tick can coordinate entity-owned behavior.
- [x] At least one entity can act from generated behavior metadata.
- [x] Playerless entity actions can create memories through normal message delivery.
- [x] Tests prove the first entity-driven autonomous behavior loop.
- [x] Deeper autonomy, behavior validation, movement, scheduling, persistence, and UI are deferred to later phases.

### Phase 6 is complete when:

- [x] Behavior metadata has a documented schema.
- [x] Generated behavior metadata is validated before unsafe use.
- [x] Invalid behavior metadata returns predictable errors.
- [x] Entity ticks execute only supported behavior actions.
- [x] At least two safe deterministic behavior actions are supported.
- [x] Behavior execution is generic and does not depend on named fixture NPCs.
- [x] Tests prove valid, invalid, and unsupported behaviors are handled correctly.
- [x] README documentation explains the behavior schema and its limits.
- [x] AI-generated behavior remains treated as untrusted data.

### Phase 7 is complete when:

- [x] A world clock boundary exists.
- [x] Manual ticking still works without the clock.
- [x] A supervised clock can coordinate world ticks.
- [x] The clock can be started and stopped predictably.
- [x] Scheduled ticks use the existing `Game.tick_world/0` / `Entity.tick/1` flow.
- [x] Tick summaries are inspectable.
- [x] Clock tests are deterministic and do not require Ollama.
- [x] Entity tick failures are isolated from the clock process.
- [x] README documentation explains how to run manual and scheduled world ticks.
- [x] Persistence, UI, and deeper simulation remain deferred.

### Phase 8 is complete when:

* [x] A `Procession.GameSession` boundary exists.
* [x] A session can start a deterministic generated game.
* [x] A session tracks its owned active entity IDs.
* [x] Session summaries expose useful runtime state as plain data.
* [x] Session cleanup stops owned entities predictably.
* [x] Cleanup is safe to call more than once.
* [x] Existing `Procession.Game` and `Procession.WorldClock` APIs still work.
* [x] Tests prove session ownership, summary, game creation, and cleanup behavior.
* [x] README or USAGE documentation explains basic session usage.
* [x] Persistence, command parsing, scoped spawning, and UI remain deferred.

### Phase 9 is complete when:

* [x] Gameplay actions can be performed through a session boundary.
* [x] Session-aware gameplay rejects entities not owned by the session.
* [x] Session-aware look, ask, talk, tick, and recent event APIs work.
* [x] Existing global gameplay APIs still work unless intentionally changed.
* [x] Session tick behavior delegates to existing world tick flow.
* [x] Session summaries include useful gameplay state.
* [x] Tests cover successful and failed session-aware gameplay actions.
* [x] Documentation includes a session-based IEx gameplay loop.
* [x] Command parsing, player entity, travel, persistence, and UI remain deferred.

### Phase 10 is complete when:

* [x] The player is represented explicitly in session state.
* [x] The player has a stable ID, location, status, and basic entity state.
* [x] The session owns the player entity.
* [x] The player is cleaned up with the rest of the session.
* [x] The session can report the player's current location.
* [x] `look` can operate relative to the player's current location.
* [x] The session can list local entities at the player's location.
* [x] Tests cover player creation, player ownership, player location, and location-relative look.
* [x] Documentation explains player entity behavior and current limitations.
* [x] Inventory, quests, combat, and player persistence remain deferred.

### Phase 11 is complete when:

* [x] A deterministic command boundary exists.
* [x] Text commands are parsed without AI.
* [x] Commands delegate to session-aware gameplay APIs.
* [x] Supported commands include look, look at, ask about, talk to, wait, and recent events.
* [x] Entity lookup works by ID and simple name matching within a session.
* [x] Unknown, malformed, and ambiguous commands return predictable errors.
* [x] Command results are returned as consistent plain data.
* [x] Tests cover supported commands and common failure cases.
* [x] Documentation includes a command-based IEx play loop.
* [x] Fuzzy parsing, AI command interpretation, CLI, and UI remain deferred.

### Phase 12 is complete when:

* [ ] Locations can define simple deterministic exits.
* [ ] Exit destinations are validated against known locations.
* [ ] The player can travel between reachable starter locations.
* [ ] Travel updates the player's location.
* [ ] Unreachable and unknown destinations return predictable errors.
* [ ] Travel commands work through the command boundary.
* [ ] `look` and local entity listing reflect the player's new location after travel.
* [ ] Tests cover valid travel, invalid travel, and location context after movement.
* [ ] Documentation explains basic travel and its limitations.
* [ ] Pathfinding, travel time, region travel, and lazy spawning remain deferred.

### Phase 13 is complete when:

* [ ] A deterministic playable vertical slice can be started.
* [ ] The vertical slice creates a session, generated starter world, and player entity.
* [ ] The player can inspect the current location.
* [ ] The player can inspect and interact with NPCs.
* [ ] The player can ask NPCs about known topics.
* [ ] The player can wait and observe world tick consequences.
* [ ] The player can travel between starter locations.
* [ ] A short multi-command play sequence works in tests.
* [ ] Documentation includes a 5-minute IEx demo script.
* [ ] CLI, Phoenix LiveView, persistence, inventory, quests, combat, and large-world expansion remain deferred.

### Phase 14 is complete when:

* [ ] A local CLI prototype can be started from the project.
* [ ] The CLI starts a deterministic playable session.
* [ ] The CLI accepts typed commands and delegates to the command boundary.
* [ ] The CLI supports help and quit.
* [ ] Command results are displayed in readable text.
* [ ] Invalid commands do not crash the CLI loop.
* [ ] Session-owned entities are cleaned up when quitting.
* [ ] The CLI does not require Ollama, Phoenix, a database, or paid services.
* [ ] Documentation explains how to run the CLI prototype and what commands are supported.
* [ ] Save/load, Phoenix LiveView, combat, quests, inventory, and AI command interpretation remain deferred.

