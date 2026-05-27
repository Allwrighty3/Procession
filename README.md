# Procession

An experimental living world engine where every NPC, faction, and location is an independent OTP process. Features emergent storytelling through message passing, hierarchical memory systems, and a procedural game generator powered by local LLMs (Ollama). Built with Phoenix LiveView.

## Current Status

Procession currently has a tested Phase 1/Phase 2 foundation:

- OTP application supervision with a registry and dynamic entity supervisor
- Entity processes backed by GenServer
- Entity-to-entity message passing
- Structured memory entries created from messages
- Hierarchical memory promotion:
  - short memory: 10 entries
  - medium memory: 50 entries
  - long memory: 200 entries
- Keyword-based memory recall
- Full memory recall in priority order

## IEx Examples

Start an entity:

```elixir
{:ok, _pid} =
  Procession.EntitySupervisor.start_entity(:alice, %{
    name: "Alice",
    type: :npc,
    location: :village_square
  })
```

Send the entity a memory-producing message:

```elixir
Procession.Entity.send_message(:alice, %{
  from: :player,
  type: :dialogue,
  content: "The blacksmith lost his hammer."
})
```

Recall memories by keyword:

```elixir
Procession.Entity.recall(:alice, "hammer")
```

Inspect memory counts:

```elixir
Procession.Entity.memory_summary(:alice)
# %{short: 1, medium: 0, long: 0}
```

Memory promotion happens automatically as messages are added:

- short memory keeps the 10 most recent memories
- overflow from short memory moves into medium memory
- overflow from medium memory moves into long memory

## Repository Map

- `lib/procession/entity.ex` - GenServer entity process, messaging, state, and recall APIs.
- `lib/procession/entity_supervisor.ex` - DynamicSupervisor for starting, stopping, looking up, and listing entities.
- `lib/procession/memory.ex` - Hierarchical memory creation, promotion, recall, and search.
- `lib/procession/application.ex` - OTP application supervision tree.
- `test/procession/entity_test.exs` - Entity, messaging, memory, recall, and lifecycle tests.
- `test/procession/memory_test.exs` - Direct memory behavior tests.

## Remaining Work

### Phase 1: Core Entity System & Message Passing

The basic entity system is working, but Phase 1 is not fully complete yet.

#### Entity lifecycle

- [x] Add a public API for stopping/removing an entity.
- [x] Add tests for stopping an entity.
- [x] Decide what should happen if an entity is started with an ID that already exists.
- [x] Add tests for duplicate entity IDs.
- [x] Add a helper for checking whether an entity exists in the registry.

#### Entity identity and lookup

- [ ] Add a consistent entity ID strategy.
  - At the moment entity IDs are atoms in tests.
  - Later systems may need string IDs, UUIDs, or generated IDs.
- [ ] Decide whether entity IDs should be atoms, strings, or another format.
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
  - Example: traits, status, location, relationships.
- [ ] Add tests for updating traits.
- [ ] Add tests for updating entity metadata.
- [ ] Decide which fields belong directly on an entity and which should become separate systems later.

#### Supervision and fault tolerance

- [ ] Add tests proving entity processes restart correctly after crashes.
- [ ] Decide whether restarted entities should keep state, reset state, or reload state.
- [ ] Add a basic crash/recovery test for the `DynamicSupervisor`.
- [ ] Decide whether persistence is needed before Phase 3 or can wait.

#### Developer ergonomics

- [ ] Add convenience functions for spawning common entity types.
  - Example: `start_npc/2`, `start_location/2`, `start_faction/2`.
- [ ] Add documentation examples for starting entities and sending messages.
- [ ] Add basic `iex` usage examples to the README.

---

### Phase 2: Hierarchical Memory System

The basic memory system is working, but Phase 2 still needs refinement before it should be considered complete.

#### Memory structure

- [x] Finalize the memory entry schema.
  - Current fields include `:content`, `:type`, `:importance`, `:timestamp`, and `:from`.
- [ ] Decide whether memory entries should include an ID.
- [ ] Add optional metadata fields.
  - Example: `:source`, `:tags`, `:location`, `:related_entities`.
- [ ] Add tests for memory entries with metadata.
- [ ] Decide whether memories should remain plain maps or become a struct.
  - Current implementation uses plain maps.

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
- [ ] Add search across memory metadata.
  - Example: search by type, source, sender, tags, or location.
- [ ] Add tests for searching by memory type.
- [ ] Add tests for searching by sender.
- [ ] Add tests for searching by tag.
- [ ] Add a `recall_recent/2` helper.
- [ ] Add a `recall_important/2` helper.
- [ ] Add a `recall_by_type/2` helper.

#### Entity memory API

- [x] Add basic entity-facing recall APIs.
  - Implemented: `Entity.recall/2`
  - Implemented: `Entity.recall_all/1`
- [ ] Add targeted entity-facing recall APIs.
  - Example: `Entity.recall_recent(id, count)`.
  - Example: `Entity.recall_by_type(id, :dialogue)`.
  - Example: `Entity.recall_important(id, minimum_importance)`.
- [ ] Add tests for each entity recall helper.
- [ ] Decide whether `recall_all/1` should return all memories forever or require a limit.

#### Memory ordering

- [ ] Confirm desired ordering for all memory layers.
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

## Phase 1 and Phase 2 Completion Criteria

### Phase 1 is complete when:

- [x] Entities can be started, stopped, looked up, and listed.
- [x] Entities can send structured messages to each other.
- [x] Message delivery failure is handled predictably.
- [ ] Entity state can be updated through clear public APIs.
- [ ] Supervision behavior is tested.
- [ ] Basic usage is documented in the README.

### Phase 2 is complete when:

- [x] Memories use a consistent structure.
- [x] Short, medium, and long memory layers are tested.
- [x] Promotion rules are clear and tested.
- [x] Entity APIs exist for common recall operations.
- [ ] Search supports more than basic content matching.
- [x] Memory ordering is intentional and tested.
- [ ] Memory inspection/debug helpers exist.
- [x] README examples show how entity memory works.