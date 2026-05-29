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
- [ ] Document that behavior metadata is generated data, not executable code.
- [ ] Keep behavior schema logic independent from specific NPC names.
- [ ] Keep deterministic behavior fixtures available for stable tests.

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

- [ ] Defer persistence.
- [ ] Defer Phoenix LiveView.
- [ ] Defer complex calendars/time systems.
- [ ] Defer faction-scale simulation.
- [ ] Defer quest progression.
- [ ] Defer combat/conflict systems.
- [ ] Defer AI-driven autonomous planning.
- [ ] Defer multi-world or multi-session support unless unavoidable.

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
