# Procession

An experimental living world engine where every NPC, faction, and location is an independent OTP process. Features emergent storytelling through message passing, hierarchical memory systems, and a procedural game generator powered by local LLMs (Ollama). Built with Phoenix LiveView.

## Current Status

Procession has completed Phases 1–7 and is ready for the next roadmap phase.

- [x] Phase 1: Core Entity System & Message Passing
- [x] Phase 2: Hierarchical Memory System
- [x] Phase 3: Local AI Integration with Ollama
- [x] Phase 4: Procedural Game Generator
- [x] Phase 5: Gameplay Systems & Polish
- [x] Phase 6: Entity Autonomy & Behavior Schema
- [x] Phase 7: World Simulation Clock & Scheduling

See [docs/ROADMAP.md](docs/ROADMAP.md) for the detailed roadmap and completion criteria.

## Repository Map

- `mix.exs` - Mix project configuration, OTP application setup, and dependency declarations.
- `lib/procession.ex` - Top-level Procession module.
- `lib/procession/application.ex` - OTP application supervision tree; starts the registry, dynamic entity supervisor, and supervised world clock.

### Core entity system

- `lib/procession/entity.ex` - GenServer entity process, messaging APIs, state updates, recall APIs, AI response integration, memory integration, and entity-driven tick behavior.
- `lib/procession/entity_supervisor.ex` - DynamicSupervisor wrapper for starting, stopping, looking up, listing, and generating common entity types.
- `lib/procession/id.ex` - Shared string ID generation helpers for entities and memory entries.

### Memory system

- `lib/procession/memory.ex` - Hierarchical memory creation, promotion, flattening, search, and filtering helpers.
- `lib/procession/memory/entry.ex` - Structured memory entry definition used by the memory system.

### Local AI boundary

- `lib/procession/ai.ex` - Public AI boundary for local text generation requests.
- `lib/procession/ai/fake_adapter.ex` - Deterministic fake AI adapter used for tests and local development.
- `lib/procession/ai/ollama.ex` - Minimal Ollama adapter for optional local model calls.
- `lib/procession/ai/prompt.ex` - Prompt-building helpers for entity/NPC responses and generator requests.
- `lib/procession/ai/memory_context.ex` - Helper for selecting relevant memories for AI requests.

### Procedural generation

- `lib/procession/generator.ex` - Public generator boundary for deterministic world generation, blueprint validation, spawning generated worlds, relationship metadata attachment, starter memory attachment, generated behavior metadata, and optional AI-assisted generation text.
- `lib/procession/generator/prompt.ex` - Prompt-building helper for optional AI-assisted world blueprint generation.

### Gameplay systems

- `lib/procession/game.ex` - Public gameplay boundary for deterministic game setup, player-facing inspection, player actions, dialogue requests, memory queries, recent autonomous event inspection, and manual world ticks.
- `lib/procession/world_clock.ex` - Supervised world clock process for manually coordinated ticks and optional interval ticking.
- `Procession.Game.tick_world/0` coordinates entity ticks; autonomous behavior remains owned by entity state and metadata.
- `Procession.WorldClock` delegates to the existing world tick flow and does not own story logic.
- Future gameplay modules may be split out only when the public `Procession.Game` boundary becomes too large.

### Documentation

- `docs/ROADMAP.md` - Detailed phase roadmap, task checklists, and phase completion criteria.
- `docs/USAGE.md` - Copy-pasteable IEx examples for entities, memory, AI, generation, gameplay APIs, manual world ticking, and optional interval ticking.
- `docs/ARCHITECTURE.md` - Core architecture principles, OTP ownership, AI validation boundaries, behavior metadata rules, and specialized subsystem guidance.
- `docs/WORLD_GENERATION.md` - Long-term cascading world generation vision, blueprint hierarchy, lazy expansion, and selective spawning strategy.

### Tests

- `test/procession/entity_test.exs` - Entity lifecycle, messaging, supervision, state update, recall, memory integration, entity AI integration, and entity-driven tick behavior tests.
- `test/procession/entity_supervisor_test.exs` - Entity supervisor behavior tests, if split out from entity tests later.
- `test/procession/id_test.exs` - ID generation tests.
- `test/procession/memory_test.exs` - Direct memory behavior, promotion, search, metadata, and entry struct tests.
- `test/procession/ai_test.exs` - Public AI boundary tests.
- `test/procession/ai/prompt_test.exs` - Entity/NPC prompt construction tests.
- `test/procession/ai/memory_context_test.exs` - AI memory context selection tests.
- `test/procession/generator_test.exs` - Procedural generator, blueprint validation, spawning, starter memory, relationship metadata, generated behavior metadata, and optional AI-generation boundary tests.
- `test/procession/generator/prompt_test.exs` - Generator prompt construction tests.
- `test/procession/game_test.exs` - Gameplay boundary, playable world setup, player actions, dialogue, memory queries, recent event inspection, and entity-driven world tick tests.
- `test/procession/world_clock_test.exs` - Manual clock, supervised clock, interval ticking, restart behavior, and failure-isolation tests.

### Development direction

- Keep generated behavior metadata as data, not executable code.
- Treat AI-generated behavior metadata as untrusted until it is validated.
- Keep autonomous behavior owned by entities; `Procession.Game` and `Procession.WorldClock` should coordinate, not decide story logic.
- Keep interval ticking optional and disabled by default.
- Preserve the separation between generated blueprint data and live OTP processes.
- Build and test function-based APIs before adding command parsing, Phoenix LiveView, persistence, combat, inventory, quests, or deeper simulation systems.
