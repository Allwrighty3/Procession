# Procession

An experimental living world engine where every NPC, faction, and location is an independent OTP process. Features emergent storytelling through message passing, hierarchical memory systems, and a procedural game generator powered by local LLMs (Ollama). Built with Phoenix LiveView.

## Current Status

Procession has completed Phases 1–11 and is ready for the next roadmap phase.

- [x] Phase 1: Core Entity System & Message Passing
- [x] Phase 2: Hierarchical Memory System
- [x] Phase 3: Local AI Integration with Ollama
- [x] Phase 4: Procedural Game Generator
- [x] Phase 5: Gameplay Systems & Polish
- [x] Phase 6: Entity Autonomy & Behavior Schema
- [x] Phase 7: World Simulation Clock & Scheduling
- [x] Phase 8: Behavior Execution Integration
- [x] Phase 9: Game Session Runtime Boundary
- [x] Phase 10: Player Entity & Location Context
- [x] Phase 11: Deterministic Command Parser

See [docs/ROADMAP.md](docs/ROADMAP.md) for the detailed roadmap and completion criteria.

## Repository Map

- `mix.exs` - Mix project configuration, OTP application setup, and dependency declarations.
- `lib/procession.ex` - Top-level Procession module.
- `lib/procession/application.ex` - OTP application supervision tree; starts the registry, dynamic entity supervisor, and supervised world clock.
- `lib/procession/id.ex` - Shared string ID generation helpers for entities, memory entries, sessions, and generated runtime objects.

### Core entity system

- `lib/procession/entity/entity.ex` - GenServer entity process, messaging APIs, state updates, recall APIs, AI response integration, memory integration, and entity-driven tick behavior.
- `lib/procession/entity/entity_supervisor.ex` - DynamicSupervisor wrapper for starting, stopping, looking up, listing, and generating common entity types, including NPCs, locations, factions, and the session-owned player entity.

### Memory system

- `lib/procession/memory/memory.ex` - Hierarchical memory creation, promotion, flattening, search, and filtering helpers.
- `lib/procession/memory/entry.ex` - Structured memory entry definition used by the memory system.

### Local AI boundary

- `lib/procession/ai/ai.ex` - Public AI boundary for local text generation requests.
- `lib/procession/ai/fake_adapter.ex` - Deterministic fake AI adapter used for tests and local development.
- `lib/procession/ai/ollama.ex` - Minimal Ollama adapter for optional local model calls.
- `lib/procession/ai/prompt.ex` - Prompt-building helpers for entity/NPC responses and generator requests.
- `lib/procession/ai/memory_context.ex` - Helper for selecting relevant memories for AI requests.

### Procedural generation

- `lib/procession/generator/generator.ex` - Public generator boundary for deterministic world generation, blueprint validation, spawning generated worlds, relationship metadata attachment, starter memory attachment, generated behavior metadata, and optional AI-assisted generation text.
- `lib/procession/generator/prompt.ex` - Prompt-building helper for optional AI-assisted world blueprint generation.

### Gameplay, sessions, and simulation

- `lib/procession/gameplay/game.ex` - Public gameplay boundary for deterministic game setup, player-facing inspection, player actions, dialogue responder checks, memory queries, recent autonomous event inspection, and manual world ticks.
- `lib/procession/gameplay/behavior.ex` - Safe behavior schema validation and execution for generated entity behavior metadata.
- `lib/procession/gameplay/world_clock.ex` - Supervised world clock process for manually coordinated ticks and optional interval ticking.
- `lib/procession/session/game_session.ex` - Runtime game session boundary for session-owned entities, explicit player entity state, player location lookup, location-relative look, local entity discovery, session-aware gameplay helpers, cleanup, and last tick summary storage.
- `lib/procession/command/command.ex` - Deterministic text command boundary for `look`, `look at`, `ask about`, `talk to`, `wait`, and recent-event inspection commands; resolves session-owned entity IDs/names and delegates to existing session-aware gameplay APIs without owning gameplay logic.
- `Procession.Game.tick_all_live_entities/0` coordinates entity ticks; autonomous behavior remains owned by entity state and metadata.
- `Procession.WorldClock` delegates to the existing world tick flow and does not own story logic.
- `Procession.GameSession` owns active live entity IDs for one play session, including `player_main`, but does not yet provide persistence, travel, inventory, quests, or session-scoped ticking.

### Documentation

- `docs/ROADMAP.md` - Detailed phase roadmap, task checklists, and phase completion criteria.
- `docs/USAGE.md` - Copy-pasteable IEx examples for entities, memory, AI, generation, gameplay APIs, manual world ticking, game sessions, player entity state, location-relative look, local entity discovery, deterministic command parsing, command-based play loops, and optional interval ticking.
- `docs/ARCHITECTURE.md` - Core architecture principles, OTP ownership, AI validation boundaries, behavior metadata rules, and specialized subsystem guidance.
- `docs/WORLD_GENERATION.md` - Long-term cascading world generation vision, blueprint hierarchy, lazy expansion, and selective spawning strategy.

### Tests

- `test/procession/entity/entity_test.exs` - Entity lifecycle, messaging, supervision, state update, recall, memory integration, entity AI integration, and entity-driven tick behavior tests.
- `test/procession/entity/supervisor_test.exs` - Entity supervisor behavior tests.
- `test/procession/id_test.exs` - ID generation tests.
- `test/procession/memory/memory_test.exs` - Direct memory behavior, promotion, search, metadata, and entry struct tests.
- `test/procession/ai/ai_test.exs` - Public AI boundary tests.
- `test/procession/ai/prompt_test.exs` - Entity/NPC prompt construction tests.
- `test/procession/ai/memory_context_test.exs` - AI memory context selection tests.
- `test/procession/ai/ollama_test.exs` - Ollama adapter tests that do not require Ollama to be running.
- `test/procession/generator/generator_test.exs` - Procedural generator, blueprint validation, spawning, starter memory, relationship metadata, generated behavior metadata, and optional AI-generation boundary tests.
- `test/procession/generator/prompt_test.exs` - Generator prompt construction tests.
- `test/procession/gameplay/game_test.exs` - Gameplay boundary, playable world setup, player actions, dialogue responder restrictions, memory queries, recent event inspection, and entity-driven world tick tests.
- `test/procession/gameplay/behavior_test.exs` - Behavior schema validation and execution tests.
- `test/procession/gameplay/world_clock_test.exs` - Manual clock, supervised clock, interval ticking, restart behavior, and failure-isolation tests.
- `test/procession/session/game_session_test.exs` - Session runtime boundary, session ownership, explicit player entity state, player location lookup, location-relative look, local entity discovery, session-aware actions, cleanup, and tick delegation tests.
- `test/procession/command/command_test.exs` - Deterministic command parsing tests for supported commands, invalid input, unknown commands, malformed command text, entity ID/name resolution, ambiguous and unknown targets, command result shapes, and session-aware delegation.

### Development direction

- Keep generated behavior metadata as data, not executable code.
- Treat AI-generated behavior metadata as untrusted until it is validated.
- Keep autonomous behavior owned by entities; `Procession.Game` and `Procession.WorldClock` should coordinate, not decide story logic.
- Keep session ownership explicit; `Procession.GameSession` owns active live entity IDs for one play session, including `player_main`.
- Keep the player as a normal session-owned entity while avoiding assumptions that every entity is an actor or dialogue responder.
- Keep `Procession.Command` deterministic and local; command parsing should translate text into existing session-aware gameplay APIs without owning gameplay logic.
- Keep AI command interpretation, fuzzy parsing, aliases, command history, Phoenix LiveView, and full CLI behavior deferred until the deterministic command boundary is stable.
- Keep interval ticking optional and disabled by default.
- Preserve the separation between generated blueprint data and live OTP processes.
- Build and test function-based APIs before adding richer interfaces such as travel commands, inventory, quests, persistence, Phoenix LiveView, combat, or deeper simulation systems.
