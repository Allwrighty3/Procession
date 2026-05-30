# Demo

This document contains the current playable IEx demo for Procession.

Phase 13 provides a tiny deterministic vertical slice that can be played directly from IEx.

This is not the final UI, not a full game, and not a content-complete experience. It is a small playable prototype that proves the current session, command, travel, memory, behavior, and display layers work together.

## Start IEx

From the project root:

```bash
iex -S mix
```

## Start the quiet demo session

```elixir
session = Procession.Demo.start_quiet()
```

This starts a deterministic demo session and returns only the session PID so IEx does not dump the full startup summary map.

The demo starts in the deterministic starter world:

- World: `Echoes of the Old Road`
- Starting location: `Old Road Crossroads`
- Active scope: `scope_starter_area`
- Player: `player_main`

## Look at the current location

```elixir
Procession.Demo.run(session, "look")
```

Expected behavior:

- Shows the current location name and description.
- Shows available exits.
- Shows local entities at the player's current location.

At the start of the demo, the player should be at `Old Road Crossroads`, with Tobin nearby.

## Inspect Tobin

```elixir
Procession.Demo.run(session, "look at Tobin")
```

Expected behavior:

- Shows Tobin's entity summary.
- Shows Tobin's type, status, location, traits, and memory counts.

## Ask Tobin about the road

```elixir
Procession.Demo.run(session, "ask Tobin about road")
```

Expected behavior:

- Shows Tobin's relevant memory about the old road and the mine.
- Demonstrates deterministic memory lookup through the command boundary.

## Talk directly to Tobin

```elixir
Procession.Demo.run(session, "talk to Tobin: Any news from the road?")
```

Expected behavior:

- Shows deterministic dialogue from Tobin.
- Uses the current fake AI adapter by default.
- Does not require Ollama.

## Wait for the world to tick

```elixir
Procession.Demo.run(session, "wait")
```

Expected behavior:

- Ticks the session-owned active entities.
- Shows Tobin sending a warning to Mira.
- Demonstrates visible world reactivity without requiring the world clock.

The expected visible action is:

```text
npc_tobin sent npc_mira: Tobin quietly warned Mira that the mine road was watched.
```

## Travel to Briar Village

```elixir
Procession.Demo.run(session, "go to Briar Village")
```

Expected behavior:

- Moves the player from `loc_crossroads` to `loc_briar_village`.
- Uses the deterministic exit labeled `village road`.

## Look around after travel

```elixir
Procession.Demo.run(session, "look")
```

Expected behavior:

- Shows `Briar Village`.
- Shows the exit back to `loc_crossroads`.
- Shows Mira as the local entity.

## Ask Mira about the mine

```elixir
Procession.Demo.run(session, "ask Mira about mine")
```

Expected behavior:

- Shows Mira's original starter memory about Tobin and the Silent Mine.
- Shows the new memory created by Tobin's behavior during `wait`.

This proves that playerless NPC behavior can create visible memories that the player can inspect later.

## Inspect Mira's recent events

```elixir
Procession.Demo.run(session, "events for Mira")
```

Expected behavior:

- Shows recent world-tick or entity-tick events for Mira.
- Should include Tobin's warning after the player has run `wait`.

## Clean up the demo session

When finished, clean up the session-owned entities:

```elixir
Procession.Demo.stop(session)
```

Expected behavior:

- Stops the live entities owned by the demo session.
- Prints a short cleanup summary.
- Leaves no demo entities running.

## Raw command results

`Procession.Demo.run/2` prints readable text and returns `:ok`.

For debugging, use `Procession.Demo.command/2` to inspect the raw command result:

```elixir
Procession.Demo.command(session, "look")
```

For formatted text without printing, use `Procession.Demo.text/2`:

```elixir
Procession.Demo.text(session, "look")
```

## Full demo sequence

```elixir
session = Procession.Demo.start_quiet()

Procession.Demo.run(session, "look")
Procession.Demo.run(session, "look at Tobin")
Procession.Demo.run(session, "ask Tobin about road")
Procession.Demo.run(session, "talk to Tobin: Any news from the road?")
Procession.Demo.run(session, "wait")
Procession.Demo.run(session, "go to Briar Village")
Procession.Demo.run(session, "look")
Procession.Demo.run(session, "ask Mira about mine")
Procession.Demo.run(session, "events for Mira")

Procession.Demo.stop(session)
```

## Deterministic behavior and optional AI

The starter world is deterministic. The same generated locations, NPCs, exits, memories, and starter behavior are used each time.

The demo uses the current fake AI adapter by default, so dialogue is deterministic and does not require Ollama.

Ollama-backed dialogue remains optional.

## Current Phase 13 limits

The Phase 13 demo intentionally defers:

- Full CLI
- Phoenix LiveView
- Inventory
- Quests
- Combat
- Save/load
- Large-world expansion
- AI command parsing
- Lazy spawning and hydration
- Pathfinding and travel time

The purpose of this demo is to prove the current Elixir/OTP simulation loop is cohesive and playable from IEx before building a richer interface.
