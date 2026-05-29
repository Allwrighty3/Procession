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

`Procession.Game.tick_world/0` does not own story logic. It coordinates a tick by asking live entities to act from their own state and metadata.

Before the tick, Mira has no recent autonomous world events:

```elixir
Procession.Game.recent_events("npc_mira")
# {:ok, []}
```

Manually tick the world:

```elixir
Procession.Game.tick_world()
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

The clock does not replace `Procession.Game.tick_world/0`. Manual ticking through `Procession.Game.tick_world/0` remains available. The clock simply provides a small GenServer boundary that can coordinate ticks, remember the latest tick summary, and track how many ticks it has coordinated.

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

* `Procession.Game.tick_world/0` directly coordinates one manual world tick.
* `Procession.WorldClock.tick(clock)` asks a clock process to coordinate one world tick and remember the result.
* Neither API starts an automatic background loop.
* Scheduled ticking is intentionally not enabled yet.

Clean up generated entities when experimenting in IEx:

```elixir
Enum.each(game.locations ++ game.npcs ++ game.factions, fn id ->
  Procession.EntitySupervisor.stop_entity(id)
end)
```

AI is not required for manual world ticking or manual clock ticking. Both paths are deterministic and local.

