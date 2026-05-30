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

## Gameplay / Phase 5 Usage

Phase 5 adds a small player-facing gameplay boundary through `Procession.Game`.

The goal is to keep gameplay actions as plain, testable function calls before adding command parsing, Phoenix LiveView, persistence, combat, inventory, or quest systems.

Phase 5 also proves the first manually triggered, entity-driven autonomous behavior loop. The world can change without direct player action, but the behavior still belongs to entities through their own state and metadata.

Start the app in IEx:

```bash
iex -S mix
```

Create a deterministic playable world:

```elixir
{:ok, game} =
  Procession.Game.new_game("a frontier village near a haunted mine")
```

The result includes the generated world name and live entity IDs:

```elixir
game.name
# "Echoes of the Old Road"

game.locations
# ["loc_crossroads", "loc_briar_village", "loc_silent_mine"]

game.npcs
# ["npc_mira", "npc_tobin", "npc_elin"]

game.factions
# ["faction_roadwardens"]
```

Inspect a live entity directly:

```elixir
Procession.Game.look("npc_mira")
```

Or inspect through the action API:

```elixir
Procession.Game.perform(:look, entity_id: "npc_mira")
```

The result is plain data:

```elixir
{:ok,
 %{
   id: "npc_mira",
   name: "Mira",
   type: :npc,
   location: "loc_briar_village",
   status: :idle,
   traits: %{role: "innkeeper", temperament: "watchful"},
   relationships: [
     %{
       to: "npc_tobin",
       type: :distrusts,
       description: "Mira thinks Tobin knows more about the mine than he admits."
     }
   ],
   description: nil,
   memory_summary: %{short: 1, medium: 0, long: 0}
 }}
```

Ask what an NPC knows about a topic:

```elixir
Procession.Game.ask_about("npc_mira", "Tobin")
```

Or ask through the action API:

```elixir
Procession.Game.perform(:ask_about,
  entity_id: "npc_mira",
  topic: "Tobin"
)
```

This returns matching memory entries as data:

```elixir
{:ok, memories} =
  Procession.Game.ask_about("npc_mira", "Tobin")

Enum.map(memories, & &1.content)
# ["Tobin was seen near the Silent Mine after sundown."]
```

Talk to an NPC through the gameplay boundary:

```elixir
Procession.Game.talk_to(
  "npc_mira",
  "What do you know about Tobin?",
  adapter: Procession.AI.FakeAdapter
)
```

Or talk through the action API:

```elixir
Procession.Game.perform(:talk_to,
  entity_id: "npc_mira",
  message: "What do you know about Tobin?",
  adapter: Procession.AI.FakeAdapter
)
```

Using the fake adapter keeps this deterministic for tests and local examples.

Missing or invalid gameplay targets return predictable errors:

```elixir
Procession.Game.look("npc_missing")
# {:error, :entity_not_found}

Procession.Game.perform(:look, [])
# {:error, :missing_target}

Procession.Game.perform(:ask_about, entity_id: "npc_mira")
# {:error, :missing_topic}

Procession.Game.perform(:talk_to, entity_id: "npc_mira")
# {:error, :missing_message}

Procession.Game.perform(:dance, entity_id: "npc_mira")
# {:error, :invalid_action}
```

The current Phase 5 gameplay loop is deterministic and does not require Ollama:

```elixir
{:ok, game} =
  Procession.Game.new_game("a frontier village near a haunted mine")

Procession.Game.perform(:look, entity_id: "npc_mira")

Procession.Game.perform(:ask_about,
  entity_id: "npc_mira",
  topic: "Tobin"
)

Procession.Game.perform(:talk_to,
  entity_id: "npc_mira",
  message: "What do you know about Tobin?",
  adapter: Procession.AI.FakeAdapter
)
```

### Manual entity-driven world tick

Phase 5 also proves the first playerless entity-driven behavior loop.

`Procession.Game.tick_all_live_entities/0` does not own story logic. It coordinates a tick by asking live entities to act from their own state and metadata.

Before the tick, Mira has no recent autonomous world events:

```elixir
Procession.Game.recent_events("npc_mira")
# {:ok, []}
```

Manually tick the world:

```elixir
Procession.Game.tick_all_live_entities()
```

The tick summary is plain data:

```elixir
{:ok,
 %{
   entities_ticked: 7,
   actions: [
     %{
       status: :ok,
       action: :send_message,
       from: "npc_tobin",
       to: "npc_mira",
       type: :rumor,
       content: "Tobin quietly warned Mira that the mine road was watched."
     }
   ]
 }}
```

After the tick, Mira has a memory created by Tobin’s entity-owned behavior:

```elixir
Procession.Game.recent_events("npc_mira")
# {:ok, [%Procession.Memory.Entry{...}]}
```

The deterministic starter world uses Tobin as a concrete fixture, but the runtime behavior is generic: entities act from `metadata.behaviors`, not from hardcoded game-level scripts.

Clean up generated entities when experimenting in IEx:

```elixir
Enum.each(game.locations ++ game.npcs ++ game.factions, fn id ->
  Procession.EntitySupervisor.stop_entity(id)
end)
```

AI is not required for the deterministic gameplay loop or manual world tick. Optional local AI remains available through the existing AI and entity response APIs, but gameplay inspection, memory queries, and the first entity-driven behavior loop are deterministic for now.

### Manual world clock

Phase 7 adds a manually controlled world clock process.

The clock does not replace `Procession.Game.tick_all_live_entities/0`. Manual ticking through `Procession.Game.tick_all_live_entities/0` remains available. The clock simply provides a small GenServer boundary that can coordinate ticks, remember the latest tick summary, and track how many ticks it has coordinated.

Start a deterministic playable world:

```elixir
{:ok, game} =
  Procession.Game.new_game("a frontier village near a haunted mine")
```

Start a manually controlled clock:

```elixir
{:ok, clock} = Procession.WorldClock.start_link([])
```

Trigger one tick through the clock:

```elixir
Procession.WorldClock.tick(clock)
```

The result includes the normal world tick summary plus the clock tick number:

```elixir
{:ok,
 %{
   clock_tick: 1,
   entities_ticked: 7,
   actions: [
     %{
       status: :ok,
       action: :send_message,
       from: "npc_tobin",
       to: "npc_mira",
       type: :rumor,
       content: "Tobin quietly warned Mira that the mine road was watched."
     },
     %{
       status: :ok,
       action: :change_status,
       entity_id: "npc_elin",
       old_status: :idle,
       new_status: :alert
     }
   ]
 }}
```

Inspect the latest clock-coordinated tick:

```elixir
Procession.WorldClock.last_tick(clock)
```

Inspect how many ticks the clock has coordinated:

```elixir
Procession.WorldClock.tick_count(clock)
# 1
```

Manual clock ticks still use entity-owned behavior metadata. The clock does not own story logic, execute behavior directly, or create autonomous background simulation.

Manual ticks and clock ticks are different entry points into the same world tick behavior:

* `Procession.Game.tick_all_live_entities/0` directly coordinates one manual world tick.
* `Procession.WorldClock.tick(clock)` asks a clock process to coordinate one world tick and remember the result.
* Neither API starts an automatic background loop.
* Scheduled interval ticking is optional and disabled by default.

Clean up generated entities when experimenting in IEx:

```elixir
Enum.each(game.locations ++ game.npcs ++ game.factions, fn id ->
  Procession.EntitySupervisor.stop_entity(id)
end)
```

AI is not required for manual world ticking or manual clock ticking. Both paths are deterministic and local.

### Optional interval ticking

The world clock can optionally tick on an interval.

Interval ticking is disabled by default. Starting the app does not automatically start background simulation.

Start a deterministic playable world:

```elixir
{:ok, game} =
  Procession.Game.new_game("a frontier village near a haunted mine")
```

Start an anonymous manual clock for experimentation:

```elixir
{:ok, clock} = Procession.WorldClock.start_link(name: nil)
```

Start interval ticking every second:

```elixir
Procession.WorldClock.start_interval(clock, 1_000)
# :ok
```

Check whether interval ticking is running:

```elixir
Procession.WorldClock.interval_running?(clock)
# true
```

Inspect the current tick count:

```elixir
Procession.WorldClock.tick_count(clock)
```

Inspect the latest interval-coordinated tick:

```elixir
Procession.WorldClock.last_tick(clock)
```

Stop interval ticking:

```elixir
Procession.WorldClock.stop_interval(clock)
# :ok
```

Confirm interval ticking has stopped:

```elixir
Procession.WorldClock.interval_running?(clock)
# false
```

Interval ticks still call the same world tick behavior as manual ticks. The clock coordinates ticks; entities still own behavior execution through their own state and metadata.

Clean up generated entities when experimenting in IEx:

```elixir
Enum.each(game.locations ++ game.npcs ++ game.factions, fn id ->
  Procession.EntitySupervisor.stop_entity(id)
end)
```

AI is not required for interval ticking. Interval ticking is deterministic and local unless entity behavior itself is later expanded to call AI through a validated boundary.

## Game Sessions

Game sessions track which live entities belong to one active play session.

A session does not generate world content directly, execute entity behavior, or own the world clock. It delegates game creation to `Procession.Game`, tracks active entity IDs, and can clean up those live entities when the session is finished.

Sessions are the first step toward larger worlds where broad blueprint data can exist without every generated entity being spawned as a live OTP process.

### Start a session

```elixir
{:ok, session} = Procession.GameSession.start_link()

Procession.GameSession.summary(session)
```

Expected shape:

```elixir
%{
  session_id: "session_...",
  world: nil,
  active_entities: [],
  active_scope: nil,
  status: :new
}
```

### Create a generated game through a session

```elixir
{:ok, session} = Procession.GameSession.start_link()

{:ok, summary} =
  Procession.GameSession.new_game(session, "a quiet frontier town")

summary.status
summary.world.name
summary.active_entities
```

Expected values:

```elixir
:active
"Echoes of the Old Road"
[
  "loc_crossroads",
  "loc_briar_village",
  "loc_silent_mine",
  "npc_mira",
  "npc_tobin",
  "npc_elin",
  "faction_roadwardens"
]
```

The session delegates deterministic game creation to `Procession.Game.new_game/1`, then records the generated locations, NPCs, and factions as session-owned active entities.

### Inspect a session summary

```elixir
Procession.GameSession.summary(session)
```

Expected shape after creating a game:

```elixir
%{
  session_id: "session_...",
  world: %{
    name: "Echoes of the Old Road",
    description: "...",
    prompt: "a quiet frontier town",
    locations: ["loc_crossroads", "loc_briar_village", "loc_silent_mine"],
    npcs: ["npc_mira", "npc_tobin", "npc_elin"],
    factions: ["faction_roadwardens"],
    relationships: 2,
    starter_memories: 2
  },
  active_entities: [
    "loc_crossroads",
    "loc_briar_village",
    "loc_silent_mine",
    "npc_mira",
    "npc_tobin",
    "npc_elin",
    "faction_roadwardens"
  ],
  active_scope: nil,
  status: :active
}
```

### List active session entities

```elixir
Procession.GameSession.active_entities(session)
```

Expected result:

```elixir
[
  "loc_crossroads",
  "loc_briar_village",
  "loc_silent_mine",
  "npc_mira",
  "npc_tobin",
  "npc_elin",
  "faction_roadwardens"
]
```

Session ownership is tracked with plain string IDs. Generated IDs are not converted into atoms.

### Check whether a session owns an entity

```elixir
Procession.GameSession.owns_entity?(session, "npc_mira")
Procession.GameSession.owns_entity?(session, "npc_not_real")
Procession.GameSession.owns_entity?(session, :npc_mira)
```

Expected result:

```elixir
true
false
false
```

### Tick the world after session game creation

```elixir
{:ok, tick_summary} = Procession.WorldClock.tick()

tick_summary.entities_ticked
tick_summary.successful_actions
tick_summary.failed_actions
```

Expected shape:

```elixir
%{
  clock_tick: 1,
  entities_ticked: 7,
  actions: [...],
  successful_actions: [...],
  failed_actions: [...]
}
```

For now, `Procession.WorldClock` still ticks all live entities. Sessions do not own private clocks yet, and session-scoped ticking is intentionally deferred until ownership and cleanup are stable.

### Clean up a session

```elixir
cleanup_summary = Procession.GameSession.cleanup(session)

cleanup_summary
```

Expected cleanup shape:

```elixir
%{
  stopped: [
    "loc_crossroads",
    "loc_briar_village",
    "loc_silent_mine",
    "npc_mira",
    "npc_tobin",
    "npc_elin",
    "faction_roadwardens"
  ],
  missing: [],
  status: :cleaned_up
}
```

The session keeps its owned entity IDs for inspection after cleanup, but the live entity processes are stopped.

```elixir
Procession.GameSession.summary(session).status
Procession.GameSession.active_entities(session)
Procession.EntitySupervisor.exists?("npc_mira")
```

Expected result after cleanup:

```elixir
:cleaned_up

[
  "loc_crossroads",
  "loc_briar_village",
  "loc_silent_mine",
  "npc_mira",
  "npc_tobin",
  "npc_elin",
  "faction_roadwardens"
]

false
```

### Cleanup is safe to call more than once

```elixir
Procession.GameSession.cleanup(session)
```

Expected shape on a later cleanup call:

```elixir
%{
  stopped: [],
  missing: [
    "loc_crossroads",
    "loc_briar_village",
    "loc_silent_mine",
    "npc_mira",
    "npc_tobin",
    "npc_elin",
    "faction_roadwardens"
  ],
  status: :cleaned_up
}
```

### Current limitations

Game sessions currently own live entity IDs only. They do not yet provide:

- persistence or save/load behavior
- player entity creation
- command parsing
- private per-session clocks
- session-scoped ticking
- scoped travel
- lazy world expansion
- inactive blueprint hydration

Inactive blueprint scopes and selective spawning are still future work.
### Session-aware gameplay helpers

`Procession.GameSession` provides a session-aware boundary for player-facing actions.

The existing `Procession.Game` helpers still work globally, but the session helpers first check whether the target entity belongs to the active session.

```elixir
{:ok, session} = Procession.GameSession.start_link(session_id: "session_demo")

{:ok, game} =
  Procession.GameSession.new_game(session, "a quiet frontier town")

game.world_name
# => "Echoes of the Old Road"

game.active_entity_count
# => 7

npc_id =
  Enum.find(game.active_entities, &String.starts_with?(&1, "npc_"))

{:ok, look_summary} =
  Procession.GameSession.look(session, npc_id)

look_summary.name

{:ok, memories} =
  Procession.GameSession.ask_about(session, npc_id, "road")

{:ok, dialogue} =
  Procession.GameSession.talk_to(
    session,
    npc_id,
    "What do you know about the old road?",
    adapter: Procession.AI.FakeAdapter
  )

{:ok, tick_summary} =
  Procession.GameSession.tick(session)

tick_summary.entities_ticked
tick_summary.failed_actions

{:ok, events} =
  Procession.GameSession.recent_events(session, npc_id)

session_summary = Procession.GameSession.summary(session)

session_summary.world_name
session_summary.active_entity_count
session_summary.last_tick_summary

Procession.GameSession.cleanup(session)
```

Session-aware helpers reject entities that do not belong to the session:

```elixir
Procession.GameSession.look(session, "npc_not_owned")
# => {:error, :entity_not_in_session}

Procession.GameSession.ask_about(session, "npc_not_owned", "road")
# => {:error, :entity_not_in_session}
```

The generic action helper can route supported gameplay actions without parsing text commands:

```elixir
Procession.GameSession.perform(session, :look, entity_id: npc_id)

Procession.GameSession.perform(
  session,
  :ask_about,
  entity_id: npc_id,
  topic: "road"
)

Procession.GameSession.perform(
  session,
  :talk_to,
  entity_id: npc_id,
  message: "Hello.",
  adapter: Procession.AI.FakeAdapter
)

Procession.GameSession.perform(session, :recent_events, entity_id: npc_id)

Procession.GameSession.perform(session, :tick)
```

`GameSession.tick/1` currently delegates to `Procession.Game.tick_all_live_entities/0`. It is session-routed, but not yet scoped to only session-owned entities.

## Player Entity and Location Context

Phase 10 introduces the player as explicit session state.

The first player model is intentionally small and deterministic. The player is a normal `Procession.Entity` process owned by the session. This gives the player an ID, location, status, metadata, and access to the existing entity memory system without adding inventory, quests, stats, combat, persistence, or command parsing yet.

Start a session and create a deterministic game:

```elixir
{:ok, session} = Procession.GameSession.start_link(session_id: "session_demo")

{:ok, summary} =
  Procession.GameSession.new_game(session, "a quiet frontier town")
```

The session summary now includes the player:

```elixir
summary.player_id
# "player_main"

summary.active_entities
# [
#   "player_main",
#   "loc_crossroads",
#   "loc_briar_village",
#   "loc_silent_mine",
#   "npc_mira",
#   "npc_tobin",
#   "npc_elin",
#   "faction_roadwardens"
# ]
```

The player is session-owned:

```elixir
Procession.GameSession.player(session)
# "player_main"

Procession.GameSession.owns_entity?(session, "player_main")
# true
```

The player is also a normal live entity:

```elixir
Procession.GameSession.look(session, "player_main")
```

Expected shape:

```elixir
{:ok,
 %{
   id: "player_main",
   name: "Player",
   type: :player,
   location: "loc_crossroads",
   status: :idle,
   traits: %{},
   relationships: [],
   description: nil,
   memory_summary: %{short: 0, medium: 0, long: 0}
 }}
```

### Player location

The session can report the player's current location:

```elixir
Procession.GameSession.player_location(session)
# {:ok, "loc_crossroads"}
```

Before a game is created, there is no player yet:

```elixir
{:ok, empty_session} = Procession.GameSession.start_link()

Procession.GameSession.player(empty_session)
# nil

Procession.GameSession.player_location(empty_session)
# {:error, :player_not_found}
```

If the player entity has been stopped unexpectedly, location lookup returns an entity error instead of crashing:

```elixir
Procession.EntitySupervisor.stop_entity("player_main")

Procession.GameSession.player_location(session)
# {:error, :entity_not_found}
```

### Location-relative look

`Procession.GameSession.look/1` looks at the player's current location.

```elixir
{:ok, location_summary} = Procession.GameSession.look(session)

location_summary.id
# "loc_crossroads"

location_summary.type
# :location
```

Location-relative look also includes session-owned entities at the player's current location:

```elixir
location_summary.local_entities
# ["npc_tobin"]
```

Use `look/2` when inspecting a specific session-owned entity:

```elixir
Procession.GameSession.look(session, "npc_mira")
```

The generic action helper also supports location-relative look:

```elixir
Procession.GameSession.perform(session, :look)
```

Use `entity_id` to look at a specific target through the action helper:

```elixir
Procession.GameSession.perform(session, :look, entity_id: "npc_mira")
```

### Local entity discovery

The session can list live, session-owned entities at the player's current location:

```elixir
Procession.GameSession.local_entities(session)
# {:ok, ["npc_tobin"]}
```

The player is not included in the local entity list. Entities in other locations are excluded. Live global entities that are not owned by the session are also excluded.

This keeps local discovery scoped to the active session instead of every process currently registered in the VM.

### Dialogue capability boundary

The gameplay boundary now treats dialogue response as a capability.

NPCs can generate dialogue responses:

```elixir
Procession.GameSession.talk_to(
  session,
  "npc_mira",
  "What do you know about the old road?",
  adapter: Procession.AI.FakeAdapter
)
```

Non-NPC entities are not treated as dialogue responders:

```elixir
Procession.GameSession.talk_to(
  session,
  "player_main",
  "Hello, me.",
  adapter: Procession.AI.FakeAdapter
)
# {:error, :entity_not_talkable}

Procession.GameSession.talk_to(
  session,
  "loc_crossroads",
  "Nice weather.",
  adapter: Procession.AI.FakeAdapter
)
# {:error, :entity_not_talkable}
```

This does not mean players or locations can never receive messages. It only means `talk_to/4` is for asking a target entity to generate a dialogue response, and the first supported dialogue responders are NPCs.

### Player memory decision

The player has access to the existing entity memory system because the player is a normal entity process.

Phase 10 does not automatically create player memories from player actions yet. Automatic journaling should wait until command parsing, travel, and player-facing event formatting are clearer.

Richer player memory, journaling, quest logs, inventory, stats, combat, save/load, and character creation are intentionally deferred.

## Deterministic Command Parser

`Procession.Command` provides a small deterministic text command boundary.

The command parser translates simple player command strings into existing session-aware gameplay APIs. It does not own gameplay logic, does not call AI, and does not provide a CLI loop yet.

### Start a command-ready session

```elixir
{:ok, session} = Procession.GameSession.start_link(session_id: "session_command_demo")
{:ok, summary} = Procession.GameSession.new_game(session, "a quiet frontier town")
```

### Look around

```elixir
Procession.Command.run(session, "look")
```

This looks at the player's current location.

### Look at a specific entity

Use an exact entity ID:

```elixir
Procession.Command.run(session, "look at npc_mira")
```

Or use an exact entity name:

```elixir
Procession.Command.run(session, "look at Mira")
```

Entity IDs are matched first. Entity names are matched second. Name lookup is limited to session-owned entities.

Unknown targets return:

```elixir
{:error, :entity_not_found}
```

Ambiguous names return:

```elixir
{:error, {:ambiguous_entity, matches}}
```

### Ask an NPC about a topic

```elixir
Procession.Command.run(session, "ask Mira about road")
```

This delegates to the session-aware memory query flow.

### Talk to an NPC

```elixir
Procession.Command.run(session, "talk to Mira: Hello there")
```

This delegates to the session-aware dialogue flow. Non-NPC entities are not valid dialogue responders.

### Wait

```elixir
Procession.Command.run(session, "wait")
```

This coordinates one session/world tick.

### Inspect recent events

```elixir
Procession.Command.run(session, "events for Mira")
```

This returns recent autonomous events for a session-owned entity.

### Tiny command-based play loop

```elixir
commands = [
  "look",
  "look at Mira",
  "ask Mira about road",
  "talk to Mira: Hello there",
  "wait",
  "events for Mira"
]

Enum.map(commands, fn command ->
  {command, Procession.Command.run(session, command)}
end)
```

### Command parser limits

The Phase 11 command parser is intentionally small and deterministic.

Deferred:

* fuzzy command parsing
* natural language AI command parsing
* aliases and shortcuts
* command history
* full CLI loop
* Phoenix LiveView

## Phase 12: Travel, Exits, and Active Scope

Phase 12 adds simple deterministic travel between known starter locations.

Travel is intentionally small in this phase:

* Locations expose exits as plain metadata.
* The player can move only through reachable exits.
* Travel is session-aware.
* Command travel delegates to the session API.
* Active scope is tracked as plain session data.
* Maps, pathfinding, travel time, locked exits, random encounters, lazy spawning, hydration, region-to-region travel, and large-world scope loading are deferred.

### Location exits

Generated starter locations include deterministic exits in location metadata.

Example exit shape:

```elixir
%{to: "loc_briar_village", label: "village road"}
```

Example IEx usage:

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, _summary} = Procession.GameSession.new_game(session, "anything")

{:ok, location} = Procession.GameSession.look(session)

location.id
# "loc_crossroads"

location.exits
# [
#   %{to: "loc_briar_village", label: "village road"},
#   %{to: "loc_silent_mine", label: "mine road"}
# ]
```

Only location summaries include exits. NPCs, factions, and players do not expose exit data.

### Player travel

Use `Procession.GameSession.travel/2` to move the player to a reachable location.

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, _summary} = Procession.GameSession.new_game(session, "anything")

Procession.GameSession.player_location(session)
# {:ok, "loc_crossroads"}

Procession.GameSession.travel(session, "loc_briar_village")
# {:ok, %{from: "loc_crossroads", to: "loc_briar_village", via: "village road"}}

Procession.GameSession.player_location(session)
# {:ok, "loc_briar_village"}
```

Travel requires the destination to be reachable from the player's current location.

Example unreachable destination:

```elixir
Procession.GameSession.travel(session, "loc_silent_mine")
# {:error, :destination_unreachable}
```

Example unknown destination:

```elixir
Procession.GameSession.travel(session, "loc_nowhere")
# {:error, :unknown_destination}
```

Example invalid destination input:

```elixir
Procession.GameSession.travel(session, nil)
# {:error, :invalid_destination}
```

### Command-based travel

The deterministic command boundary supports simple travel commands:

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, _summary} = Procession.GameSession.new_game(session, "anything")

Procession.Command.run(session, "go to Briar Village")
# {:ok, %{command: :travel_to, ...}}

Procession.Command.run(session, "travel to loc_silent_mine")
# {:ok, %{command: :travel_to, ...}}
```

Destination resolution follows the existing command pattern:

1. Exact entity ID first.
2. Exact entity name second.
3. Session-owned locations only.
4. Reachability is checked by the session travel API.

Malformed travel commands return predictable errors:

```elixir
Procession.Command.run(session, "go to")
# {:error, :missing_target}

Procession.Command.run(session, "travel to")
# {:error, :missing_target}
```

### Looking before and after travel

`look` is location-relative. After travel, it reflects the player's new location and local entities.

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, _summary} = Procession.GameSession.new_game(session, "anything")

{:ok, before_travel} = Procession.Command.run(session, "look")

before_travel.result.id
# "loc_crossroads"

before_travel.result.local_entities
# ["npc_tobin"]

{:ok, _travel} = Procession.Command.run(session, "go to Briar Village")

{:ok, after_travel} = Procession.Command.run(session, "look")

after_travel.result.id
# "loc_briar_village"

after_travel.result.local_entities
# ["npc_mira"]
```

`Procession.GameSession.local_entities/1` also updates after travel:

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, _summary} = Procession.GameSession.new_game(session, "anything")

Procession.GameSession.local_entities(session)
# {:ok, ["npc_tobin"]}

Procession.GameSession.travel(session, "loc_briar_village")
# {:ok, %{from: "loc_crossroads", to: "loc_briar_village", via: "village road"}}

Procession.GameSession.local_entities(session)
# {:ok, ["npc_mira"]}
```

Local entity listing remains session-aware. Entities from other sessions or unrelated global entities are not treated as local.

### Active scope

Sessions now track a simple active scope value.

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, summary} = Procession.GameSession.new_game(session, "anything")

summary.active_scope
# "scope_starter_area"

Procession.GameSession.summary(session).active_scope
# "scope_starter_area"
```

In Phase 12, all starter locations are still spawned and live. `active_scope` is plain session data for future active-scope simulation, lazy spawning, hydration, and large-world generation.

No lazy spawning or scope loading is implemented yet.

### Scoped ticking

`Procession.GameSession.tick/1` now ticks only session-owned active entities.

```elixir
{:ok, session} = Procession.GameSession.start_link()
{:ok, _summary} = Procession.GameSession.new_game(session, "anything")

Procession.GameSession.tick(session)
# {:ok, %{entities_ticked: ..., actions: ..., successful_actions: ..., failed_actions: ...}}
```

The lower-level helper:

```elixir
Procession.Game.tick_entities(entity_ids)
```

ticks an explicit list of entity IDs.

The temporary global helper:

```elixir
Procession.Game.tick_all_live_entities()
```

ticks every live entity currently registered. It is primarily useful as a temporary global debugging or smoke-test helper. Session gameplay should prefer `Procession.GameSession.tick/1`.

### Deferred from Phase 12

The following systems are intentionally deferred:

* pathfinding
* travel time
* random encounters
* locked exits
* region-to-region travel
* lazy spawning and hydration
* large-scale maps
* NPC autonomous movement through behavior metadata

NPCs can still be moved at the raw entity level through `Procession.Entity.move_to/2`, but autonomous NPC movement should later be added through validated behavior metadata rather than through the player travel API.

