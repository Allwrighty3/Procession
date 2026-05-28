# Procession

An experimental living world engine where every NPC, faction, and location is an independent OTP process. Features emergent storytelling through message passing, hierarchical memory systems, and a procedural game generator powered by local LLMs (Ollama). Built with Phoenix LiveView.

## Current Status

Procession has completed its initial Phase 1 and Phase 2 foundation.

- [x] Phase 1: Core Entity System & Message Passing
- [x] Phase 2: Hierarchical Memory System
- [ ] Phase 3: Local AI Integration with Ollama
- [ ] Phase 4: Procedural Game Generator
- [ ] Phase 5: Gameplay Systems & Polish

The current codebase includes:

- OTP application supervision with a registry and dynamic entity supervisor
- Entity processes backed by GenServer
- String-based runtime IDs with generated ID helpers
- Entity lifecycle helpers for starting, stopping, looking up, and listing entities
- Entity-to-entity message passing
- Public entity state updates for status, location, traits, and metadata
- Basic supervision crash/recovery coverage
- Structured memory entries with IDs, tags, metadata, timestamps, and importance
- Hierarchical memory promotion:
  - short memory: 10 entries
  - medium memory: 50 entries
  - long memory: 200 entries
- Keyword-based memory recall
- Targeted recall by type, sender, tag, metadata, recency, and importance
- Full memory recall in priority order
- Memory inspection through `Entity.memory_summary/1`

Current focus: Phase 3 — adding a small local AI boundary before wiring in Ollama.

## IEx Examples

Start the app in an interactive shell:

```bash
iex -S mix
```

Create a location with a generated string ID:

```elixir
{:ok, village_id, _pid} =
  Procession.EntitySupervisor.create_location(%{
    name: "Village Square"
  })
```

Create an NPC with a generated string ID:

```elixir
{:ok, alice_id, _pid} =
  Procession.EntitySupervisor.create_npc(%{
    name: "Alice",
    location: village_id
  })
```

Start another NPC with an explicit string ID:

```elixir
{:ok, _pid} =
  Procession.EntitySupervisor.start_npc("npc_bob", %{
    name: "Bob",
    location: village_id
  })
```

Send a message from one entity to another:

```elixir
Procession.Entity.send_to(alice_id, "npc_bob", %{
  type: :dialogue,
  content: "The blacksmith lost his hammer.",
  importance: 3,
  tags: [:quest, :blacksmith],
  metadata: %{
    location: village_id,
    related_entities: ["npc_bob"]
  }
})
```

Recall memories by keyword:

```elixir
Procession.Entity.recall("npc_bob", "hammer")
```

Recall memories by tag:

```elixir
Procession.Entity.recall_by_tag("npc_bob", :quest)
```

Recall memories by metadata:

```elixir
Procession.Entity.recall_by_metadata("npc_bob", :location, village_id)
```

Inspect memory counts:

```elixir
Procession.Entity.memory_summary("npc_bob")
# %{short: 1, medium: 0, long: 0}
```

Memory promotion happens automatically as messages are added:

- short memory keeps the 10 most recent memories
- overflow from short memory moves into medium memory
- overflow from medium memory moves into long memory

## Repository Map

- `mix.exs` - Mix project configuration, OTP application setup, and dependency declarations.
- `lib/procession/application.ex` - OTP application supervision tree; starts the registry and dynamic entity supervisor.
- `lib/procession/entity.ex` - GenServer entity process, messaging APIs, state updates, recall APIs, and memory integration.
- `lib/procession/entity_supervisor.ex` - DynamicSupervisor wrapper for starting, stopping, looking up, listing, and generating common entity types.
- `lib/procession/id.ex` - Shared string ID generation helpers for entities and memory entries.
- `lib/procession/memory.ex` - Hierarchical memory creation, promotion, flattening, search, and filtering helpers.
- `lib/procession/memory/entry.ex` - Structured memory entry definition used by the memory system.
- `test/procession/entity_test.exs` - Entity lifecycle, messaging, supervision, state update, recall, and helper API tests.
- `test/procession/id_test.exs` - ID generation tests.
- `test/procession/memory_test.exs` - Direct memory behavior, promotion, search, metadata, and entry struct tests.

Phase 3 work should add new modules under `lib/procession/ai/` or similar rather than crowding AI behavior into the entity or memory modules.

## Remaining Work

The detailed phase checklists include both completion blockers and future refinement ideas. The formal criteria for considering Phase 1 and Phase 2 complete are listed at the bottom of this section.

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

- [ ] Add a small `Procession.AI` module as the public boundary for AI requests.
- [ ] Define a simple request function.
  - Example: `Procession.AI.generate(prompt, opts \\ [])`
- [ ] Standardize return values.
  - Example: `{:ok, response_text}` or `{:error, reason}`
- [ ] Keep the AI boundary separate from entity and memory modules.
- [ ] Add tests for the public AI API using a deterministic fake adapter.

#### Adapter design

- [ ] Define a simple adapter behavior for AI backends.
  - Example: `generate(prompt, opts)`.
- [ ] Add a fake adapter for tests and development.
- [ ] Add an Ollama adapter only after the fake adapter works.
- [ ] Keep adapter selection simple.
  - Example: pass adapter through opts first.
  - Defer application config until needed.
- [ ] Avoid adding a supervised AI process unless there is a clear need.

#### Ollama integration

- [ ] Decide the first local model to target.
  - Example: `llama3.2`, `mistral`, or another small local model.
- [ ] Add a minimal Ollama client that calls the local HTTP API.
- [ ] Support only the simplest text generation request first.
- [ ] Handle basic connection failures.
  - Example: Ollama not running.
  - Example: model not installed.
- [ ] Add tests that do not require Ollama to be running.
- [ ] Add optional/manual test instructions for testing against a real local Ollama server.

#### Prompt structure

- [ ] Define a small prompt-building helper.
- [ ] Start with plain strings before introducing complex prompt structs.
- [ ] Add a basic system/context convention.
  - Example: world context, entity state, relevant memories, player input.
- [ ] Keep prompts request-based.
- [ ] Do not create persistent chat threads per entity.

#### Entity integration preparation

- [ ] Decide the first entity AI use case.
  - Example: generate a short NPC response.
- [ ] Add an explicit entity-facing function only after the AI boundary works.
  - Example: `Entity.generate_response(id, player_message)`.
- [ ] Include only structured entity state and selected memories in the request.
- [ ] Keep AI output as data returned to the caller first.
- [ ] Do not automatically mutate entity state from AI output in the first version.
- [ ] Add tests proving entity AI integration can be exercised with the fake adapter.

#### Memory integration preparation

- [ ] Decide how many memories should be included in an AI request.
  - Example: recent 5 plus important memories.
- [ ] Add a helper for selecting AI-relevant memories.
- [ ] Keep memory selection deterministic before using AI summarization.
- [ ] Defer LLM-generated memory summaries until basic generation works.
- [ ] Add tests for memory selection before connecting it to Ollama.

#### Developer ergonomics

- [ ] Add README examples for calling the AI boundary from IEx.
- [ ] Add README instructions for installing and running Ollama locally.
- [ ] Document how to pull the chosen local model.
- [ ] Document what happens if Ollama is not running.
- [ ] Keep all Phase 3 examples small and copy-pasteable.

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

- [ ] A public AI boundary exists outside the entity and memory modules.
- [ ] AI calls use a small adapter behavior.
- [ ] A fake adapter supports deterministic tests.
- [ ] An Ollama adapter can make a local request to a locally running model.
- [ ] Ollama connection/model errors are handled predictably.
- [ ] At least one simple IEx example can generate local AI text.
- [ ] Entities can optionally request AI-generated output through a controlled public API.
- [ ] Entity AI requests use structured state and selected memories.
- [ ] Tests do not require Ollama to be installed or running.
- [ ] README documentation explains local setup and basic usage.
