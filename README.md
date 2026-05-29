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

## Local AI / Ollama Usage

Phase 3 uses a small AI boundary before wiring local LLM behavior into entities.

The public API is:

```elixir
Procession.AI.generate(prompt, opts \\ [])
```

By default, this uses the deterministic fake adapter. That keeps tests and early development from requiring Ollama to be installed or running.

```elixir
Procession.AI.generate("Describe the village blacksmith.")
# {:ok, "AI response to: Describe the village blacksmith."}
```

To call a real local Ollama model, pass the Ollama adapter explicitly:

```elixir
Procession.AI.generate(
  "Describe a tired village blacksmith in one sentence.",
  adapter: Procession.AI.Ollama,
  model: "llama3.2:1b"
)
```

A successful local response looks like:

```elixir
{:ok, "The village blacksmith slumped against the forge..."}
```

### Generating an NPC response

Entities can request AI-generated output through a controlled public API:

```elixir
Procession.Entity.generate_response(
  "npc_bob",
  "Can you help me find the blacksmith's hammer?",
  adapter: Procession.AI.FakeAdapter
)
```

### Installing Ollama in WSL / Ubuntu

If developing inside WSL, install Ollama inside WSL rather than relying on a Windows install.

First install `zstd`, which the Ollama installer requires for extraction:

```bash
sudo apt-get update
sudo apt-get install -y zstd
```

Then install Ollama:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Verify the client is installed:

```bash
ollama -v
```

If WSL prints a warning like this:

```text
Warning: could not connect to a running Ollama instance
```

that usually means the Ollama client is installed but the Ollama server is not running yet.

### Starting Ollama manually in WSL

Some WSL installs do not run `systemd` by default, so the Ollama service may not start automatically.

Start the server manually in one terminal:

```bash
ollama serve
```

Leave that terminal open.

In a second terminal, pull the small test model:

```bash
ollama pull llama3.2:1b
```

Then test the model directly:

```bash
ollama run llama3.2:1b "Say hello in one sentence."
```

### Testing Procession against local Ollama

From the repo root:

```bash
iex -S mix
```

Then run:

```elixir
Procession.AI.generate(
  "Describe a tired village blacksmith in one sentence.",
  adapter: Procession.AI.Ollama,
  model: "llama3.2:1b"
)
```

Expected shape:

```elixir
{:ok, "...generated text..."}
```

If Ollama is not running, the adapter should return an error tuple instead of crashing:

```elixir
{:error, {:ollama_unavailable, reason}}
```

This keeps local AI calls request-based and explicit. Entities should not directly depend on Ollama yet.

## Procedural World Generation

Phase 4 adds a small procedural generator that creates a world blueprint before spawning live entity processes.

The first generator path is deterministic and does not require Ollama.

```elixir
{:ok, blueprint} =
  Procession.Generator.generate_world("a frontier village near a haunted mine")
```

The generated blueprint is plain data:

```elixir
blueprint.name
# "Echoes of the Old Road"

length(blueprint.locations)
# 3

length(blueprint.npcs)
# 3

length(blueprint.factions)
# 1
```

Blueprints can be validated before they are spawned:

```elixir
Procession.Generator.validate_blueprint(blueprint)
# :ok
```

Spawning is a separate step. This keeps generation separate from live OTP processes:

```elixir
{:ok, summary} = Procession.Generator.spawn_world(blueprint)
```

The summary shows what was created:

```elixir
summary
# %{
#   locations: ["loc_crossroads", "loc_briar_village", "loc_silent_mine"],
#   npcs: ["npc_mira", "npc_tobin", "npc_elin"],
#   factions: ["faction_roadwardens"],
#   relationships: 2,
#   starter_memories: 2
# }
```

Generated entities use the normal registry and supervisor:

```elixir
Procession.EntitySupervisor.exists?("npc_mira")
# true
```

Starter memories are attached through the existing entity message/memory behavior:

```elixir
Procession.Entity.recall_all("npc_mira")
```

Generated relationships are stored in entity metadata first:

```elixir
mira = Procession.Entity.get_state("npc_mira")

mira.metadata.relationships
# [
#   %{
#     to: "npc_tobin",
#     type: :distrusts,
#     description: "Mira thinks Tobin knows more about the mine than he admits."
#   }
# ]
```

Clean up generated entities when experimenting in IEx:

```elixir
Enum.each(summary.locations ++ summary.npcs ++ summary.factions, fn id ->
  Procession.EntitySupervisor.stop_entity(id)
end)
```

### Optional AI-assisted world generation

Procession can also ask the existing local AI boundary to generate world blueprint text.

This path is optional. It does not parse AI output, validate the result as a blueprint, or spawn live entities yet.

```elixir
{:ok, result} =
  Procession.Generator.generate_world_ai(
    "a frontier village near a haunted mine",
    adapter: Procession.AI.FakeAdapter
  )
```

The result contains the prompt sent to the AI boundary and the generated text response:

```elixir
result.prompt
# "...small world blueprint..."

result.response
# "AI response to: ..."
```

To test against local Ollama manually, make sure Ollama is running, then pass the Ollama adapter:

```elixir
Procession.Generator.generate_world_ai(
  "a frontier village near a haunted mine",
  adapter: Procession.AI.Ollama,
  model: "llama3.2:1b"
)
```

AI-assisted output is treated as untrusted text for now. The deterministic generator remains the safe path for creating and spawning playable worlds.

## Repository Map

- `mix.exs` - Mix project configuration, OTP application setup, and dependency declarations.
- `lib/procession.ex` - Top-level Procession module.
- `lib/procession/application.ex` - OTP application supervision tree; starts the registry and dynamic entity supervisor.

### Core entity system

- `lib/procession/entity.ex` - GenServer entity process, messaging APIs, state updates, recall APIs, AI response integration, and memory integration.
- `lib/procession/entity_supervisor.ex` - DynamicSupervisor wrapper for starting, stopping, looking up, listing, and generating common entity types.
- `lib/procession/id.ex` - Shared string ID generation helpers for entities and memory entries.

### Memory system

- `lib/procession/memory.ex` - Hierarchical memory creation, promotion, flattening, search, and filtering helpers.
- `lib/procession/memory/entry.ex` - Structured memory entry definition used by the memory system.

### Local AI boundary

- `lib/procession/ai.ex` - Public AI boundary for local text generation requests.
- `lib/procession/ai/fake_adapter.ex` - Deterministic fake AI adapter used for tests and local development.
- `lib/procession/ai/ollama.ex` - Minimal Ollama adapter for optional local model calls.
- `lib/procession/ai/prompt.ex` - Prompt-building helpers for entity/NPC responses.
- `lib/procession/ai/memory_context.ex` - Helper for selecting relevant memories for AI requests.

### Procedural generation

- `lib/procession/generator.ex` - Public generator boundary for deterministic world generation, blueprint validation, spawning generated worlds, relationship metadata attachment, starter memory attachment, and optional AI-assisted generation text.
- `lib/procession/generator/prompt.ex` - Prompt-building helper for optional AI-assisted world blueprint generation.

### Gameplay systems

- Phase 5 gameplay modules should be added under `lib/procession/` without crowding the entity, memory, generator, or AI modules.
- Planned first module: `lib/procession/game.ex` - Public gameplay boundary for player-facing inspection and actions.
- Future gameplay modules may be split out only when the public `Procession.Game` boundary becomes too large.

### Tests

- `test/procession/entity_test.exs` - Entity lifecycle, messaging, supervision, state update, recall, memory integration, and entity AI integration tests.
- `test/procession/entity_supervisor_test.exs` - Entity supervisor behavior tests, if split out from entity tests later.
- `test/procession/id_test.exs` - ID generation tests.
- `test/procession/memory_test.exs` - Direct memory behavior, promotion, search, metadata, and entry struct tests.
- `test/procession/ai_test.exs` - Public AI boundary tests.
- `test/procession/ai/prompt_test.exs` - Entity/NPC prompt construction tests.
- `test/procession/ai/memory_context_test.exs` - AI memory context selection tests.
- `test/procession/generator_test.exs` - Procedural generator, blueprint validation, spawning, starter memory, relationship metadata, and optional AI-generation boundary tests.
- `test/procession/generator/prompt_test.exs` - Generator prompt construction tests.
- Future Phase 5 tests should start with `test/procession/game_test.exs`.

### Development direction

- Phase 5 work should begin with `Procession.Game` as a small player-facing API.
- Keep gameplay orchestration separate from `Entity`, `Memory`, `Generator`, and `AI`.
- Build and test function-based gameplay APIs before adding command parsing, Phoenix LiveView, persistence, combat, inventory, or quests.

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
- [ ] Start with plain function calls before adding LiveView or UI behavior.
- [ ] Standardize return values.
  - Example: `{:ok, result}` or `{:error, reason}`
- [ ] Add tests for the public gameplay API.
- [ ] Avoid creating a supervised gameplay process unless stateful orchestration is clearly needed.

#### World inspection

- [x] Add a basic function for inspecting a live entity.
  - Example: `Procession.Game.look(entity_id)`
- [x] Return a player-friendly summary of entity state.
  - Example fields: `:id`, `:name`, `:type`, `:location`, `:status`, `:traits`, `:relationships`, `:memory_summary`.
- [x] Handle missing entities predictably.
  - Example: `{:error, :entity_not_found}`
- [ ] Add tests for inspecting NPCs, locations, and factions.
- [x] Add tests for missing entity lookup.
- [x] Keep the first inspection result as plain data, not formatted prose.

#### Generated world gameplay setup

- [ ] Add a helper for creating a playable test world.
  - Example: `Procession.Game.new_game(prompt)`
- [ ] Use the deterministic generator first.
- [ ] Validate the generated blueprint before spawning.
- [ ] Spawn the generated world through `Procession.Generator.spawn_world/1`.
- [ ] Return a summary that includes the world name and created entity IDs.
- [ ] Do not use AI generation for the first playable setup path.
- [ ] Add tests proving a new playable world can be created from a prompt.

#### Player actions

- [ ] Define a tiny player action API.
  - Example: `Procession.Game.perform(action, opts)`
- [ ] Start with one or two simple deterministic actions.
  - Example: `:look`
  - Example: `:talk`
  - Example: `:move`
- [ ] Keep actions as plain data before introducing command parsing.
- [ ] Return action results without mutating more state than necessary.
- [ ] Handle invalid actions predictably.
- [ ] Add tests for valid and invalid player actions.

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

- [ ] Add a simple player-to-NPC dialogue helper.
  - Example: `Procession.Game.talk_to(npc_id, player_message, opts \\ [])`
- [ ] Use `Entity.generate_response/3` for optional AI-backed dialogue.
- [ ] Support deterministic fake-adapter dialogue in tests.
- [ ] Keep generated dialogue as returned data first.
- [ ] Do not automatically mutate NPC state from AI dialogue yet.
- [ ] Add tests proving dialogue can be requested safely.

#### Memory-driven interaction

- [ ] Add a simple helper for recalling what an NPC knows.
  - Example: `Procession.Game.ask_about(npc_id, topic)`
- [ ] Use existing entity recall helpers.
- [ ] Keep recall deterministic before adding AI summarization.
- [ ] Return matching memories as data.
- [ ] Add tests for asking about known and unknown topics.

#### Gameplay loop preparation

- [ ] Define the first tiny gameplay loop.
  - Example: create world, inspect NPC, talk to NPC, inspect memory.
- [ ] Keep the loop runnable from IEx.
- [ ] Add README examples for the first playable loop.
- [ ] Avoid building command parsing until the function-based loop works.
- [ ] Avoid building Phoenix LiveView until core gameplay APIs feel stable.

#### Developer ergonomics

- [ ] Add README examples for `Procession.Game.look/1`.
- [ ] Add README examples for creating a playable deterministic world.
- [ ] Add README examples for the first player action.
- [ ] Keep all examples copy-pasteable in IEx.
- [ ] Document which Phase 5 features are deterministic and which optionally use AI.
- [ ] Document cleanup steps for generated test worlds.

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

- [ ] A public gameplay boundary exists outside the entity, memory, generator, and AI modules.
- [ ] The player can inspect live entities through a simple gameplay API.
- [ ] Missing or invalid gameplay targets return predictable errors instead of crashing.
- [ ] A deterministic playable world can be created from a prompt.
- [ ] Generated worlds can be inspected through gameplay functions after spawning.
- [ ] At least one simple player action works through a public gameplay API.
- [ ] Basic movement works between valid generated locations.
- [ ] Player-to-NPC dialogue can be requested safely.
- [ ] Dialogue tests do not require Ollama to be installed or running.
- [ ] NPC memories can be queried through a gameplay-facing helper.
- [ ] The first tiny gameplay loop is runnable from IEx.
- [ ] README documentation explains the first playable loop.
- [ ] Tests cover the core gameplay boundary and first player actions.
