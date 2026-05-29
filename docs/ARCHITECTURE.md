# Architecture Notes

Procession is an experimental single-player RPG simulation engine built around Elixir/OTP. The core architectural idea is that major world entities such as NPCs, factions, locations, and events can exist as lightweight supervised processes that communicate through message passing.

The project should remain Elixir/OTP-first. Elixir owns the simulation kernel: entity processes, supervision, message passing, world ticks, behavior validation and execution, memory ownership, gameplay state, and the player-facing API.

Other tools and languages may eventually be used for specialized subsystems, but they should not replace Elixir as the owner of live simulation state.

## Core Design Principles

### Elixir owns the simulation

Elixir should remain responsible for:

* Entity process lifecycle
* Supervision and fault tolerance
* Message passing
* Entity state
* Memory ownership
* Behavior validation
* Behavior execution
* World ticks
* Gameplay APIs
* Spawning and hydrating live simulation scopes
* Deciding what generated content becomes active

Other systems may compute, analyze, generate, render, or search, but Elixir should remain authoritative over state and gameplay decisions.

### Blueprints are inert; entities are live

Generated world data should be treated as inert blueprint data until it is validated and intentionally spawned.

A generated NPC, faction, settlement, or region does not automatically need to be a live OTP process. Large parts of the world may remain as blueprint data, summaries, persisted records, or inactive scopes until the player approaches, asks about them, or the simulation needs them.

This distinction should remain clear:

* Blueprints describe possible or known world content
* Validation checks whether generated content is safe and structurally valid
* Spawning turns selected blueprint content into live OTP processes
* Live entities own active state and participate in message passing and ticking

### AI output is untrusted

AI-generated output should be treated as candidate data, not truth.

Before generated content is spawned or executed, it should be validated. This applies especially to:

* Entity IDs
* Location references
* Relationship references
* Starter memories
* Behavior metadata
* Faction goals
* Generated conflicts
* World hierarchy references

AI should suggest structured content. Elixir should validate, accept, reject, transform, and own it.

### Behavior metadata is data, not executable code

Autonomous behavior should be represented as validated metadata with a safe action vocabulary.

Prefer behavior metadata like:

```elixir
%{
  trigger: :world_tick,
  action: :change_status,
  conditions: [
    %{type: :has_location}
  ],
  status: :alert
}
```

Avoid executable behavior scripts or arbitrary function calls.

Behavior validation should ensure that generated metadata uses only supported triggers, supported actions, valid required fields, and safe references. Validation must never execute behavior.

### Game orchestration and story logic are separate

`Procession.Game` should be the player-facing gameplay boundary. It may coordinate actions, world setup, dialogue, inspection, and ticking, but it should not become the owner of all story logic.

Autonomous behavior should remain owned by entity state and metadata. The game boundary coordinates. Entities act.

### Start simple, preserve future shape

The project should favor small, testable milestones that produce visible progress. However, early implementation should avoid assumptions that would block the long-term vision.

Avoid hidden assumptions such as:

* All generated content is flat
* All generated content is immediately spawned
* All entities are always active
* All location references point to live GenServers
* World generation happens in one request
* A world is only a small local village
* NPC behavior can assume the entire world is loaded

It is fine for early implementations to be small, but they should not make large-scale cascading generation painful later.

## Specialized Systems and Future Languages

Procession should remain Elixir/OTP-first. Elixir/Erlang are the correct tools for the concurrent actor-based simulation model.

However, some future needs are likely to come up where Elixir may not be the strongest practical tool. When those needs appear, recommend the best specialized tool for that subsystem rather than forcing everything into Elixir or adding languages for novelty.

### Python

Python is a practical option for:

* ML/AI tooling
* Embeddings
* Semantic memory experiments
* Prompt evaluation
* World-generation analysis
* Data diagnostics
* Offline content-processing tools

Python should not own:

* NPC processes
* World ticks
* Live gameplay state
* Entity supervision
* Core message passing

Python should be treated as a side tool, offline pipeline, or narrow local service when needed.

### Rust

Rust is a practical option for narrow performance-heavy pure functions such as:

* Pathfinding
* Spatial indexing
* Graph traversal
* Procedural generation bottlenecks
* Compression
* Serialization
* Fast similarity search

Rust should compute answers. It should not own gameplay state.

Good boundary:

```elixir
Procession.Pathfinding.find_route(world_graph, from_id, to_id)
```

Bad boundary:

```elixir
Procession.NativeNpcRuntime.tick_all_npcs()
```

### JavaScript / TypeScript

JavaScript or TypeScript may be appropriate only where Phoenix LiveView needs richer client-side interaction, such as:

* Maps
* Graphs
* Timelines
* Drag-and-drop editors
* Debugging visualizations

Avoid a large SPA unless LiveView clearly becomes insufficient.

### Godot

Godot may be considered later if visual presentation becomes the bottleneck.

If used, Godot should be a graphical client. Elixir should remain authoritative over simulation state.

### Lua / scripting

Lua or another scripting layer should be deferred until validated behavior metadata proves too rigid.

Prefer behavior-as-data over executable scripts unless scripting becomes clearly necessary and can be sandboxed, validated, and tested.

## Practical Rule for Adding Complexity

Add another subsystem, language, or architectural layer only when:

1. It solves a real practical problem
2. The boundary is narrow and testable
3. The feature produces visible gameplay, tooling, or debugging value
4. Elixir remains the owner of state, orchestration, and gameplay decisions
