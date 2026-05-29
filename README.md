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

