# Roadmap

The detailed historical phase checklists live in [ROADMAP_ARCHIVE.md](ROADMAP_ARCHIVE.md). This file tracks completed milestones, current priorities, upcoming phases, and phase completion criteria.

---

## Completed Phases

- [x] Phase 1: Core Entity System & Message Passing
- [x] Phase 2: Hierarchical Memory System
- [x] Phase 3: Local AI Integration with Ollama
- [x] Phase 4: Procedural Game Generator
- [x] Phase 5: Gameplay Systems & Polish
- [x] Phase 6: Entity Autonomy & Behavior Schema
- [x] Phase 7: World Simulation Clock & Scheduling
- [x] Phase 8: Game Session & Active Entity Ownership
- [x] Phase 9: Session-Aware Gameplay API
- [x] Phase 10: Player Entity & Location Context
- [x] Phase 11: Deterministic Command Parser
- [x] Phase 12: Basic Travel & Active Scope Preparation
- [x] Phase 13: First Playable Vertical Slice
- [x] Phase 14: Tiny Local CLI Loop
- [x] Phase 15: Capability Boundaries & Playability Polish
- [x] Phase 16: AI-Backed NPC Dialogue Through Safe Boundaries
- [x] Phase 17: Dialogue Context & Grounded AI Responses

Detailed historical checklists live in [ROADMAP_ARCHIVE.md](ROADMAP_ARCHIVE.md).

---

### Current Focus

- [ ] Phase 18: NPC Interaction AI Skill & Training Foundation

### Near-Term

- [ ] Phase 19: Starter Area Content Depth & World Reactivity
- [ ] Phase 20: Rumor / Thread Prototype

### Larger Simulation Direction

- [ ] Phase 21: Active Scope & Selective Simulation
- [ ] Phase 22: Cascading World Generation Foundation
- [ ] Phase 23: AI-Assisted Validated Expansion

---

## Current Focus

Procession now has a tiny local playable CLI loop. The next work should improve the playable experience only where it strengthens the underlying living-world simulation.

The project should not drift into being only a terminal text adventure. The CLI is a visibility layer for the Elixir/OTP simulation engine.

Current priorities:

- Clarify what different entity types are allowed to do.
- Improve the playable shell only where it strengthens simulation boundaries.
- Bring AI interaction closer to the core experience through explicit, safe boundaries.
- Keep simulation authority in Elixir.
- Keep AI output validated before it can affect state.
- Improve starter-area world reactivity enough to expose simulation behavior.
- Preserve the long-term path toward active scopes, cascading world generation, and selective spawning.

---

## Architecture Guardrails

### AI is the creative core; Elixir is the authoritative scaffold

AI is central to Procession’s purpose. It provides the creative force behind dynamic dialogue, world expansion, emergent rumors, faction tension, behavior proposals, and cascading content generation.

Elixir/OTP provides the armor and scaffolding that keeps AI output usable, testable, and safe. AI may propose possibilities, but Elixir validates, constrains, supervises, and simulates accepted possibilities.

Procession should not minimize AI. It should contain and structure AI so that its creativity can drive the world without turning the simulation into inconsistent Lovecraftian nonsense  — unless that is the explicit design goal of a validated world, region, faction, entity, or event.

The intended loop is:

1. AI proposes expressive or generative content.
2. Elixir parses and validates the proposal.
3. Validated data becomes memory, behavior metadata, thread state, scope data, or blueprint content.
4. OTP processes simulate the accepted world state.
5. The player experiences the result through CLI, IEx, or future UI adapters.

AI is therefore core to the experience, but not sovereign over the state.

### Do not replace Laboon with an iceberg

Do not make convenient early substitutions that preserve a surface role while destroying future payoff.

In Procession, a placeholder should preserve the real architectural meaning of the thing it represents. Prefer a small truthful version over a substitute that works for the current demo but breaks later systems.

### General simulation rules

- Elixir remains authoritative over simulation state.
- Entities own their state, memory, and behavior metadata.
- `Procession.Game`, `Procession.GameSession`, `Procession.WorldClock`, `Procession.Command`, `Procession.Command.Display`, `Procession.CLI`, and `Procession.Demo` coordinate or adapt; they should not own entity behavior.
- Behavior metadata remains data, not executable code.
- AI-generated content is untrusted until validated.
- Ollama may generate expression, dialogue, rumors, or candidate content, but Elixir decides what actually changes.
- CLI and display formatting are player-facing adapters only.
- Inactive world content should remain blueprint or summary data until activated.
- Do not spawn the whole world as live OTP processes.
- Prefer visible, testable progress over abstract cleanup.

---

## Phase 18: NPC Interaction AI Skill & Training Foundation

Phase 18 establishes `npc_interaction` as Procession’s first task-specific AI skill and runs the first local training experiment for that skill.

This is a major foundation phase. It is expected to be larger and deeper than recent roadmap phases because it covers architecture, validation, evals, dataset creation, training, comparison, and an optional integration decision.

The goal is not perfect dialogue. The goal is a reproducible path for creating, evaluating, training, and optionally using a specialized NPC interaction model that performs more consistently than the base general-purpose model.

Further fine-tuning may happen in later phases as Procession gains more characters, relationships, memories, factions, world-generation needs, and failure cases.

### Gate 1: Skill boundary and ownership

- [x] **Primary task: Add the NPC interaction skill boundary**
  - [x] Add `Procession.AI.NPCInteraction`.
  - [x] Route grounded NPC dialogue generation through `NPCInteraction`.
  - [x] Keep `Entity` responsible for behavior execution.
  - [x] Prevent `Entity` from directly owning prompt/model details.
  - [x] Keep `Procession.Dialogue.Context` responsible for authoritative context construction.
  - [x] Keep `Procession.AI.Prompt` responsible for prompt text construction.
  - [x] Keep `Procession.AI` responsible for adapter dispatch.

- [x] **Primary task: Preserve current play and test behavior**
  - [x] Preserve fake-adapter-safe tests.
  - [x] Preserve the AI-enabled CLI demo path.
  - [x] Keep normal deterministic CLI/demo behavior available.
  - [x] Ensure default tests do not require Ollama.
  - [x] Keep AI output non-authoritative.

- [x] **Primary task: Prove the boundary works**
  - [x] Add tests proving grounded dialogue uses the NPC interaction boundary.
  - [x] Verify grounded dialogue still works through `Procession.Command`.
  - [x] Verify grounded dialogue still works through the CLI path.
  - [x] Verify existing normal dialogue still works.

### Gate 2: Validation and safety checks

- [x] **Primary task: Add the NPC interaction validator**
  - [x] Add `Procession.AI.NPCInteraction.Validator`.
  - [x] Define a validation function for generated NPC dialogue.
    - Example: `validate_response(context, response)`
  - [x] Return inspectable validation results.
    - Example: `{:ok, response}`
    - Example: `{:error, validation_errors}`
  - [x] Keep validation separate from prompt construction.
  - [x] Do not mutate entity state, memory, behavior metadata, or world state during validation.

- [ ] **Primary task: Detect target identity violations**
  - [x] Detect when Tobin claims to be Mira.
  - [ ] Detect when Mira claims to be Tobin.
  - [x] Detect when the target NPC introduces itself as another known active entity.
  - [x] Detect obvious “I am <other entity>” patterns.
  - [x] Keep first validation rules simple and explainable.
  - [x] Document that validation is a guardrail, not proof of truth.

- [ ] **Primary task: Detect early field-bleed failures**
  - [ ] Detect responses that assign target traits to the player.
  - [ ] Detect responses that rewrite the player’s question.
  - [ ] Detect responses that treat role labels as current activity.
  - [ ] Detect responses that express uncertainty and then invent lore.
  - [ ] Add static tests for known Phase 17 failure examples.

### Gate 3: Eval harness and baseline scoring

- [ ] **Primary task: Define the eval case format**
  - [ ] Add a small eval case data shape.
  - [ ] Include `id`.
  - [ ] Include `target_id`.
  - [ ] Include `message`.
  - [ ] Include `must_include`.
  - [ ] Include `must_include_any`.
  - [ ] Include `must_not_include`.
  - [ ] Include `expected_unknown`.
  - [ ] Include `notes`.

- [ ] **Primary task: Add starter eval cases**
  - [ ] Add `priv/evals/npc_interaction_cases.jsonl`.
  - [ ] Add at least 10 starter NPC interaction eval cases.
  - [ ] Include known-entity questions.
  - [ ] Include unknown-entity questions.
  - [ ] Include identity-preservation cases.
  - [ ] Include uncertainty cases.
  - [ ] Include field-boundary cases.
  - [ ] Include question-preservation cases.

- [ ] **Primary task: Build deterministic eval scoring**
  - [ ] Add a deterministic eval runner that can score static responses without Ollama.
  - [ ] Add tests for loading eval cases.
  - [ ] Add tests for scoring pass/fail cases.
  - [ ] Add tests for identity failure detection.
  - [ ] Add tests for field-bleed detection where practical.
  - [ ] Ensure default tests do not require Ollama.

- [ ] **Primary task: Establish the base model baseline**
  - [ ] Add a manual Ollama eval runner if simple.
  - [ ] Run the base model against the starter eval set.
  - [ ] Record base model results.
  - [ ] Document common base model failures.

### Gate 4: Training data format and corpus

- [ ] **Primary task: Define the training example format**
  - [ ] Include the same context shape used by `Procession.AI.NPCInteraction`.
  - [ ] Include target NPC identity.
  - [ ] Include speaker facts.
  - [ ] Include location facts.
  - [ ] Include known scene entities.
  - [ ] Include other known NPCs.
  - [ ] Include relevant target memories.
  - [ ] Include the player message.
  - [ ] Include the expected bounded NPC response.

- [ ] **Primary task: Create the first curated training corpus**
  - [ ] Create 25–50 curated `npc_interaction` examples.
  - [ ] Add known entity question examples.
  - [ ] Add unknown entity question examples.
  - [ ] Add location question examples.
  - [ ] Add occupation/role question examples.
  - [ ] Add relationship question examples.
  - [ ] Add target identity preservation examples.
  - [ ] Add field-boundary examples.
  - [ ] Add uncertainty-instead-of-invention examples.
  - [ ] Add concise playable voice examples.

- [ ] **Primary task: Keep the corpus non-authoritative**
  - [ ] Do not treat training examples as world truth.
  - [ ] Do not import generated model outputs into entity memory.
  - [ ] Do not create behavior metadata from training examples.
  - [ ] Keep generated/exported files separate from runtime state.
  - [ ] Document that examples teach bounded behavior, not authoritative lore.

### Gate 5: Training export and local tooling

- [ ] **Primary task: Add training export support**
  - [ ] Add a script or Mix task to export training data.
    - Example: `mix procession.export_npc_interaction_training`
  - [ ] Keep exported training data reproducible.
  - [ ] Keep exported files separate from runtime code.
  - [ ] Add basic tests for export shape if practical.
  - [ ] Document how to regenerate the training file.

- [ ] **Primary task: Choose local training tooling**
  - [ ] Research practical local LoRA or adapter-style fine-tuning options.
  - [ ] Prefer free/local tooling.
  - [ ] Do not train a model from scratch.
  - [ ] Confirm whether `llama3.2:1b` is practical as the first experiment target.
  - [ ] Document setup steps and system assumptions.

- [ ] **Primary task: Keep training outside runtime assumptions**
  - [ ] Do not add training dependencies to the default test path.
  - [ ] Do not require training tools for normal development.
  - [ ] Keep model artifacts out of the repo unless intentionally documented.
  - [ ] Document where local model artifacts live.

### Gate 6: First local fine-tuning experiment

- [ ] **Primary task: Run the first training experiment**
  - [ ] Use the curated dataset.
  - [ ] Use `llama3.2:1b` or another practical local small model.
  - [ ] Run the first fine-tuning experiment.
  - [ ] Name the trained model clearly.
    - Example: `procession-npc-interaction:1b`
  - [ ] Record exact commands used.
  - [ ] Record training limitations and failures.

- [ ] **Primary task: Keep expectations realistic**
  - [ ] Do not require perfect dialogue.
  - [ ] Do not require the trained model to become default.
  - [ ] Treat this as a reproducible first experiment.
  - [ ] Document what would justify later fine-tuning.

### Gate 7: Model comparison and acceptance

- [ ] **Primary task: Compare base model and trained model**
  - [ ] Run the eval harness against the base model.
  - [ ] Run the eval harness against the trained model.
  - [ ] Compare identity preservation.
  - [ ] Compare context-only answering.
  - [ ] Compare field-boundary preservation.
  - [ ] Compare uncertainty behavior.
  - [ ] Compare concise NPC voice.
  - [ ] Compare question preservation.

- [ ] **Primary task: Decide whether quality improved enough**
  - [ ] Document whether the trained model performs better than the base model.
  - [ ] Document remaining weaknesses.
  - [ ] Decide whether the trained model is useful enough for optional use.
  - [ ] Do not require perfection.
  - [ ] Do not make the trained model mandatory.

### Gate 8: Optional integration and documentation

- [ ] **Primary task: Add optional trained-model usage if justified**
  - [ ] If useful, add a documented model option.
    - Example: `model: "procession-npc-interaction:1b"`
  - [ ] Keep fake adapter as the default for tests.
  - [ ] Keep Ollama opt-in for automated tests.
  - [ ] Keep AI output non-authoritative.
  - [ ] Do not allow trained model output to mutate memory, behavior metadata, entity state, or world state.

- [ ] **Primary task: Run the human acceptance script**
  - [ ] `grounded talk to Tobin: Who is Mira?`
  - [ ] `grounded talk to Tobin: Where is Mira?`
  - [ ] `grounded talk to Tobin: What is Mira's job?`
  - [ ] `grounded talk to Mira: Who is Tobin?`
  - [ ] `grounded talk to Tobin: Who is Elandra?`
  - [ ] `grounded talk to Mira: Are you Tobin?`
  - [ ] `grounded talk to Tobin: Are you Mira?`

- [ ] **Primary task: Document Phase 18 results**
  - [ ] Document `npc_interaction` as the first task-specific AI skill.
  - [ ] Document the eval workflow.
  - [ ] Document the training dataset format.
  - [ ] Document the first training experiment.
  - [ ] Document base-vs-trained results.
  - [ ] Document whether the trained model is accepted for optional use.
  - [ ] Document future fine-tuning opportunities.
  - [ ] Document future AI skill candidates:
    - `npc_actions`
    - `faction_planning`
    - `world_generation`
    - `memory_summarization`
    - `relationship_consistency`

### Deferred from Phase 18

- [ ] Defer training `npc_actions`.
- [ ] Defer training `faction_planning`.
- [ ] Defer training `world_generation`.
- [ ] Defer AI-authored behavior metadata.
- [ ] Defer AI mutation of memory.
- [ ] Defer AI mutation of world state.
- [ ] Defer making the trained model mandatory.
- [ ] Defer large-scale automated dataset generation.

---

## Phase 19: Starter Area Content Depth & World Reactivity

Phase 19 makes the current starter area more interesting while keeping the simulation deterministic and inspectable.

The goal is to improve visible world reactivity. The starter area should feel less like a static demo and more like a small living situation.

### Starter content depth

- [ ] Add richer deterministic starter memories.
- [ ] Add more useful ask-about topics.
- [ ] Add at least one additional visible NPC memory relationship.
- [ ] Add at least one visible world event that can be discovered after `wait`.
- [ ] Improve location descriptions to hint at current tensions.
- [ ] Ensure at least two NPCs have meaningful things to inspect or ask about.
- [ ] Keep demo content deterministic.
- [ ] Add tests for new starter memories and topics.

### Visible world reactivity

- [ ] Add or refine behavior metadata so `wait` creates visible consequences.
- [ ] Ensure successful actions are visible through command/display output.
- [ ] Ensure failed actions remain visible for debugging.
- [ ] Ensure player-facing event inspection can reveal changes.
- [ ] Add tests proving `wait` changes later inspection or event output.
- [ ] Add tests proving playerless behavior affects later player interaction.

### Demo experience

- [ ] Update the demo command list if new useful interactions exist.
- [ ] Add a richer 5-minute demo path.
- [ ] Keep the demo runnable without Ollama.
- [ ] Add optional AI-enhanced demo notes if Phase 16 supports them.
- [ ] Keep the demo focused on simulation behavior, not just prettier text.

### Deferred from Phase 19

- [ ] Defer full quest systems.
- [ ] Defer combat.
- [ ] Defer inventory.
- [ ] Defer save/load.
- [ ] Defer large-world expansion.

---

## Phase 20: Rumor / Thread Prototype

Phase 20 introduces a small world-thread system.

The goal is to track emerging story threads without building a rigid quest system. Threads should help the player follow world activity while preserving the simulation-first design.

### Thread model

- [ ] Define a simple thread data shape.
  - Example fields: `:id`, `:title`, `:state`, `:related_entities`, `:facts_discovered`, `:open_questions`.
- [ ] Keep threads as plain data first.
- [ ] Decide whether threads live in session state, entity memory, or a small separate module.
- [ ] Add a starter thread for the existing demo situation.
  - Example: the mine road, Tobin’s warning, Mira’s concern.
- [ ] Add tests for creating and inspecting thread data.

### Thread discovery

- [ ] Allow player actions to reveal thread facts.
- [ ] Connect existing memories/events to thread discovery where simple.
- [ ] Add a session API for listing known threads.
  - Example: `Procession.GameSession.threads(session)`
- [ ] Add a session API for inspecting one thread.
- [ ] Add command support if useful.
  - Example: `threads`
  - Example: `thread mine road`
- [ ] Add tests for thread discovery through player interaction.

### Thread progression

- [ ] Decide whether `wait` can advance a thread deterministically.
- [ ] Add one small deterministic thread progression.
- [ ] Keep progression inspectable as plain data.
- [ ] Do not create a full quest engine yet.
- [ ] Add tests proving a thread can progress.

### Display and demo

- [ ] Add display formatting for known threads.
- [ ] Add a demo sequence showing thread discovery.
- [ ] Keep output readable but not overly polished.
- [ ] Document that threads are not full quests yet.

### Deferred from Phase 20

- [ ] Defer quest rewards.
- [ ] Defer objectives/checklists unless they naturally emerge.
- [ ] Defer branching quest logic.
- [ ] Defer AI-authored thread progression.
- [ ] Defer persistence.

---

## Phase 21: Active Scope & Selective Simulation

Phase 21 returns to the long-term large-world architecture.

The goal is to formalize the difference between live active content and inactive blueprint/summary content. This prevents large worlds from becoming fully spawned GenServer forests.

### Active scope model

- [ ] Define a first active scope data shape.
  - Example fields: `:scope_id`, `:kind`, `:entity_ids`, `:location_ids`, `:faction_ids`, `:status`.
- [ ] Store active scope information in session state.
- [ ] Keep the first scope model simple and local.
- [ ] Add tests for active scope summary output.
- [ ] Document that active scope is runtime state, not the whole world.

### Scope-aware ticking

- [ ] Update session ticking to tick only active-scope entities if not already doing so.
- [ ] Keep global world ticking available for debugging if useful.
- [ ] Ensure non-active entities are not ticked through the session.
- [ ] Add tests proving session tick only affects active scope.
- [ ] Add tests proving inactive entities remain untouched.
- [ ] Keep tick summaries inspectable.

### Scope lifecycle

- [ ] Add helpers for activating a scope.
- [ ] Add helpers for deactivating a scope.
- [ ] First version may only support the starter scope.
- [ ] Do not implement full lazy generation yet.
- [ ] Add tests for activation/deactivation behavior.
- [ ] Ensure cleanup still stops live session-owned entities.

### Blueprint separation

- [ ] Document the difference between:
  - generated blueprint data
  - active scope summaries
  - live entity processes
- [ ] Avoid storing all future content as live entities.
- [ ] Add small examples in `WORLD_GENERATION.md` if useful.

### Deferred from Phase 21

- [ ] Defer region-scale generation.
- [ ] Defer save/load.
- [ ] Defer background simulation of inactive scopes.
- [ ] Defer full world maps.
- [ ] Defer multi-scope travel unless trivial.

---

## Phase 22: Cascading World Generation Foundation

Phase 22 begins the large-world generation pipeline.

The goal is not to generate everything at once. The goal is to generate broad summaries first, then expand details only when needed.

### World hierarchy

- [ ] Define a high-level world hierarchy.
  - World overview.
  - Regions.
  - Local scopes.
  - Locations.
  - NPCs.
  - Factions.
- [ ] Keep hierarchy data as blueprints/summaries first.
- [ ] Do not spawn all generated content.
- [ ] Add validation for hierarchy references.
- [ ] Add tests for valid and invalid hierarchy data.

### Region summaries

- [ ] Add deterministic region summary generation.
- [ ] Include region name, type, themes, tensions, and known factions.
- [ ] Keep summaries inert.
- [ ] Add tests for region summary shape.
- [ ] Add docs explaining inert region summaries.

### Local scope expansion

- [ ] Add a function for expanding one region/local scope into a detailed blueprint.
- [ ] Validate expanded blueprint before spawning.
- [ ] Spawn only the selected active scope.
- [ ] Add tests proving expansion does not spawn unrelated regions.
- [ ] Add tests proving invalid expansion output is rejected.

### Integration with session

- [ ] Allow a session to hold broader world summary data.
- [ ] Allow a session to activate one expanded local scope.
- [ ] Keep active scope ownership explicit.
- [ ] Add tests for activating generated scope data.

### Deferred from Phase 22

- [ ] Defer AI-generated hierarchy if deterministic generation is not stable.
- [ ] Defer persistence.
- [ ] Defer background inactive-region simulation.
- [ ] Defer large-scale pathfinding.
- [ ] Defer economic/faction simulation.

---

## Phase 23: AI-Assisted Validated Expansion

Phase 23 uses local AI to propose larger world content.

The goal is to let Ollama assist generation without making it authoritative. AI proposes. Elixir validates. Invalid content gets rejected, repaired, or ignored.

### AI expansion boundary

- [ ] Add or extend an AI-assisted generation boundary for region/scope expansion.
- [ ] Keep prompts structured.
- [ ] Keep AI output as untrusted text or parsed data until validated.
- [ ] Reuse existing AI adapter pattern.
- [ ] Ensure tests use fake adapters.
- [ ] Add manual Ollama test instructions.

### Structured output parsing

- [ ] Decide on a simple structured output format.
  - Example: JSON-like maps after parsing.
- [ ] Parse AI output into candidate blueprints.
- [ ] Validate candidate blueprints through existing validation boundaries.
- [ ] Return predictable errors for invalid AI output.
- [ ] Add tests for valid and invalid fake AI outputs.

### Safe content activation

- [ ] Ensure AI-generated content is not spawned until validated.
- [ ] Spawn only selected validated scopes.
- [ ] Keep inactive generated summaries inert.
- [ ] Add tests proving invalid AI content is not spawned.
- [ ] Add tests proving valid AI-assisted content can become an active scope.

### Diagnostics

- [ ] Add simple diagnostics for rejected AI output.
- [ ] Add prompt/response examples for local debugging.
- [ ] Consider Python tooling later for prompt evaluation or generation diagnostics.
- [ ] Do not add Python into the simulation runtime.

### Deferred from Phase 23

- [ ] Defer AI autonomous planning.
- [ ] Defer direct AI state mutation.
- [ ] Defer AI command parsing.
- [ ] Defer full persistence.
- [ ] Defer background world simulation.

---

## Phase Completion Criteria

### Phase 15 is complete when:

- [x] Basic entity capability rules exist.
- [x] Gameplay APIs return predictable errors for unsupported capabilities.
- [x] Non-talkable entities cannot be talked to.
- [x] Non-location entities cannot be traveled to.
- [x] Tick behavior boundaries are documented or enforced.
- [x] CLI/display output is clearer without owning gameplay logic.
- [x] Tests cover capability rules and common failure cases.
- [x] The playable demo loop still works.
- [x] Ollama, persistence, quests, combat, and large-world expansion remain deferred.

### Phase 16 is complete when:

- [x] Optional AI-backed NPC dialogue is available through an explicit safe path.
- [x] AI dialogue is restricted to talkable NPCs.
- [x] AI prompt context includes relevant NPC/session/player context.
- [x] AI dialogue returns text only and does not mutate game state directly.
- [x] Existing deterministic dialogue behavior remains available.
- [x] Tests use fake adapters and do not require Ollama.
- [x] Documentation explains deterministic play and AI-backed dialogue.
- [x] AI planning, AI command parsing, and AI-generated behavior mutation remain deferred.

### Phase 17 is complete when:

- [ ] A dedicated plain-data dialogue context module exists.
- [ ] Dialogue context is built from authoritative Elixir state, not AI output.
- [ ] Dialogue context includes target NPC facts, speaker facts, current location facts, known active entities, and relevant memories.
- [ ] Prompt construction consumes structured dialogue context instead of scattered ad hoc fields.
- [ ] Prompts include grounding instructions that discourage invented occupations, locations, relationships, timelines, and events.
- [ ] `GameSession.talk_to/4` uses structured dialogue context while preserving explicit adapter options and timeout support.
- [ ] CLI AI dialogue can answer simple grounded questions more consistently when answers exist in context.
- [ ] Tests cover dialogue context construction, prompt rendering, and session integration without requiring Ollama.
- [ ] Documentation explains grounded AI dialogue and makes clear that AI output is expression, not world truth.
- [ ] Long-term conversation memory, AI-generated world facts, validated rumor/thread mutation, semantic memory search, and AI command interpretation remain deferred.

### Phase 18 is complete when:

- [ ] The starter area has richer deterministic memories or topics.
- [ ] At least one `wait` action creates a visible consequence.
- [ ] Player-facing inspection can reveal new world activity.
- [ ] The demo has a richer but still deterministic play path.
- [ ] Tests prove starter content and visible reactivity.
- [ ] Documentation explains the updated starter-area demo.
- [ ] Quests, combat, inventory, persistence, and large-world expansion remain deferred.

### Phase 19 is complete when:

- [ ] A simple world-thread data model exists.
- [ ] At least one starter thread can be discovered.
- [ ] Player actions can reveal thread facts.
- [ ] Threads can be inspected through session APIs or commands.
- [ ] At least one deterministic thread progression exists if useful.
- [ ] Display output can show known threads.
- [ ] Tests cover thread discovery and inspection.
- [ ] Full quest systems, rewards, branching quests, and AI-authored progression remain deferred.

### Phase 20 is complete when:

- [ ] Active scope is represented as explicit session/runtime data.
- [ ] Session ticking can be limited to active-scope entities.
- [ ] Inactive content is not treated as live simulation.
- [ ] Scope activation/deactivation is tested at a simple level.
- [ ] Cleanup still handles live session-owned entities.
- [ ] Documentation explains active scope versus blueprint versus live process.
- [ ] Region-scale generation, persistence, and inactive background simulation remain deferred.

### Phase 21 is complete when:

- [ ] A cascading world hierarchy shape exists.
- [ ] Region summaries can be generated or represented as inert data.
- [ ] One local scope can be expanded from broader world data.
- [ ] Expanded scope data is validated before spawning.
- [ ] Only selected active scope content becomes live entity processes.
- [ ] Tests prove unrelated regions are not spawned.
- [ ] Documentation explains the broad-to-detailed generation pipeline.
- [ ] AI generation, persistence, and large-scale background simulation remain deferred unless explicitly started.

### Phase 22 is complete when:

- [ ] Local AI can propose region or scope expansion content through a controlled boundary.
- [ ] AI output is parsed into candidate data.
- [ ] Candidate data is validated before use.
- [ ] Invalid AI output returns predictable errors and is not spawned.
- [ ] Valid AI-assisted content can become an active scope.
- [ ] Tests use fake adapters and do not require Ollama.
- [ ] Manual Ollama instructions exist.
- [ ] AI remains non-authoritative over simulation state.