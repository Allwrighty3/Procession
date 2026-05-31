# Procession

An experimental living world engine where every NPC, faction, and location is an independent OTP process. Features emergent storytelling through message passing, hierarchical memory systems, and a procedural game generator powered by local LLMs (Ollama). Built with Phoenix LiveView.

## Current Status

Procession has completed Phases 1–17 and is ready for the next roadmap phase.

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
- [x] Phase 12: Basic Travel & Active Scope Preparation
- [x] Phase 13: First Playable Vertical Slice
- [x] Phase 14: Tiny Local CLI Loop
- [x] Phase 15: Capability Boundaries & Playability Polish
- [x] Phase 16: AI-Backed NPC Dialogue Through Safe Boundaries
- [x] Phase 17: Dialogue Context & Grounded AI Responses

See [docs/ROADMAP.md](docs/ROADMAP.md) for the detailed roadmap and completion criteria.

## Repository Map

### Core application

* `lib/procession/application.ex`

  * Starts the OTP supervision tree.
  * Owns startup for the entity registry, dynamic entity supervisor, and other runtime services.

### Entity runtime

* `lib/procession/entity/entity.ex`

  * GenServer-backed world entity process.
  * Stores entity state, location, traits, metadata, status, and memory.
  * Supports messaging, recall, status changes, trait changes, metadata updates, movement through `move_to/2`, AI response generation, and ticking behavior metadata.

* `lib/procession/entity/entity_supervisor.ex`

  * Dynamic supervisor for live entity processes.
  * Starts players, NPCs, locations, and factions.
  * Provides lookup, existence checks, listing, and stopping helpers for registered entities.

* `lib/procession/entity/entity_registry.ex`

  * Registry used to address live entities by string ID.

### Memory

* `lib/procession/memory/memory.ex`

  * Memory creation, storage helpers, promotion, filtering, searching, and recall support.
  * Supports short, medium, and long memory layers.

### AI boundary

* `lib/procession/ai/ai.ex`

  * AI adapter boundary.
  * Keeps AI calls behind a controlled interface.

* `lib/procession/ai/fake_adapter.ex`

  * Deterministic fake AI adapter for tests and local demos.
  * Provides readable deterministic dialogue for Phase 13 demo play without requiring Ollama.

* `lib/procession/ai/ollama_adapter.ex`

  * Optional Ollama-backed adapter.

* `lib/procession/ai/prompt.ex`

  * Prompt construction helpers for NPC dialogue and generation-related AI usage.

* `lib/procession/ai/memory_context.ex`

  * Selects relevant memory context for AI prompts.

### Behavior and gameplay

* `lib/procession/gameplay/behavior.ex`

  * Validates and executes safe entity behavior metadata.
  * Behavior metadata remains data, not executable code.
  * Current supported behavior actions include message sending and status changes.

* `lib/procession/gameplay/game.ex`

  * Gameplay boundary for deterministic player-facing actions and world helpers.
  * Supports `look`, `ask_about`, `talk_to`, `recent_events`, explicit scoped ticking through `tick_entities/1`, and temporary global ticking through `tick_all_live_entities/0`.
  * `tick_all_live_entities/0` is a temporary global helper and should not be treated as the long-term session gameplay API.

* `lib/procession/gameplay/world_clock.ex`

  * Runtime world clock process for recurring ticks.
  * Supports clock start/stop behavior and tick interval handling.

### Session gameplay

* `lib/procession/session/game_session.ex`

  * Session-owned gameplay boundary.
  * Tracks session ID, player ID, generated world summary, active entities, active scope, status, and last tick summary.
  * Supports session-aware `look`, `ask_about`, `talk_to`, `recent_events`, `tick`, `travel`, `player`, `player_location`, `local_entities`, ownership checks, cleanup, and Phase 13 demo startup.
  * `start_demo/1` packages the deterministic starter world, session, player entity, active scope, and suggested demo commands into a playable setup.
  * `tick/1` is scoped to session-owned active entities.
  * `travel/2` moves the player only through reachable location exits.
  * `active_scope` currently stores `"scope_starter_area"` as plain data for future active-scope work.

### Command parsing and demo play

* `lib/procession/command/command.ex`

  * Deterministic text command boundary.
  * Parses simple text commands and delegates to `Procession.GameSession`.
  * Supported commands:

    * `look`
    * `look at <target>`
    * `ask <npc> about <topic>`
    * `talk to <npc>: <message>`
    * `wait`
    * `events for <entity>`
    * `go to <location>`
    * `travel to <location>`

  * Resolves exact entity IDs first and exact entity names second.
  * Limits resolution to session-owned entities.
  * Keeps command parsing deterministic and AI-free.

* `lib/procession/command/display.ex`

  * Formats command results into readable text for IEx demos.
  * Keeps display formatting separate from gameplay state and command execution.
  * Supports readable output for look, look-at, ask-about, talk-to, wait, travel, recent-events, and errors.

* `lib/procession/demo.ex`

  * IEx-friendly helper boundary for the Phase 13 playable vertical slice.
  * Starts quiet demo sessions, runs commands with readable output, exposes raw command results for debugging, returns formatted text when needed, and cleans up demo sessions.
  * Delegates setup to `GameSession`, command execution to `Command`, and display formatting to `Command.Display`.

### World generation

* `lib/procession/generator/generator.ex`

  * Deterministic world blueprint generation, validation, and spawning.
  * Keeps generation separate from live entity spawning.
  * Starter world currently includes locations, NPCs, factions, relationships, starter memories, behaviors, and validated location exits.
  * Location exits are stored as metadata when locations are spawned.

* `lib/procession/generator/prompt.ex`

  * Prompt helper for AI-assisted world generation preparation.

### IDs and utilities

* `lib/procession/id.ex`

  * Generates string IDs for sessions, entities, NPCs, locations, factions, and related runtime objects.

### Documentation

* `README.md`

  * Project overview, current status, phase roadmap summary, repository map, and development direction.

* `docs/USAGE.md`

  * IEx examples and practical usage notes.
  * Includes examples for entity processes, memory, AI boundaries, world generation, session gameplay, deterministic commands, travel, exits, active scope, and scoped ticking.

* `docs/DEMO.md`

  * Phase 13 playable IEx demo guide.
  * Documents the full 5-minute vertical slice: quiet startup, look, NPC inspection, asking, talking, waiting, travel, recent events, cleanup, raw command inspection, deterministic behavior, optional AI, and current demo limits.

* `docs/ROADMAP.md`

  * Detailed phased development roadmap and completion criteria.

* `docs/ARCHITECTURE.md`

  * Architecture notes and design direction.
  * Emphasizes Elixir/OTP ownership of simulation, separation between blueprints and live entities, and future large-world support.

* `docs/WORLD_GENERATION.md`

  * World-generation direction and constraints.
  * Supports cascading world generation and separation between inert generated data and live simulation processes.

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
- `test/procession/session/game_session_test.exs` - Session runtime boundary, session ownership, explicit player entity state, player location lookup, location-relative look, local entity discovery, session-aware actions, cleanup, scoped ticking, travel, active scope, and vertical slice setup tests.
- `test/procession/command/command_test.exs` - Deterministic command parsing tests for supported commands, invalid input, unknown commands, malformed command text, entity ID/name resolution, ambiguous and unknown targets, command result shapes, session-aware delegation, travel commands, and the Phase 13 multi-command vertical slice.
- `test/procession/command/display_test.exs` - Display formatting tests for readable command output, including look, ask, talk, wait, travel, recent events, and errors.
- `test/procession/demo_test.exs` - Phase 13 demo helper tests for quiet startup, readable command running, raw command access, formatted text output, recent events, cleanup, and invalid demo sessions.

## Development Direction

Recommended current development direction:

- Keep Elixir/OTP as the authoritative simulation kernel.
- Preserve the separation between inert blueprints and live entity processes.
- Treat the Phase 14 local CLI as the current baseline playable experience.
- Keep the CLI thin: it should read input, send commands to the existing session boundary, print formatted output, and clean up on exit.
- Do not move gameplay rules, command parsing, travel rules, ticking, or memory behavior into the CLI.
- Keep command parsing deterministic until the gameplay surface is stable.
- Continue expanding active scope carefully before introducing large-world lazy spawning.
- Preserve the future path toward cascading world generation without flattening the world into one always-live global map.
- Consider NPC movement later through validated behavior metadata, not through player/session travel APIs.
- Keep AI-generated data untrusted until validated.
