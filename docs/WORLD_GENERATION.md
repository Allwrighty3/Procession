# Large-Scale World Generation Vision

Procession’s long-term world generation vision is large-scale, hierarchical, and cascading. The goal is not merely to generate a small RPG village or a fully detailed world in one request. The goal is to support broad world generation that can expand progressively from high-level structure into increasingly detailed local simulation.

World generation should be designed as a staged pipeline:

1. World overview / premise
2. Major regions
3. Subregions, kingdoms, territories, or biomes
4. Settlements, landmarks, routes, and local conflicts
5. Factions and power structures
6. NPCs and relationships
7. Starter memories, rumors, secrets, and local knowledge
8. Validated behavior metadata
9. Live entity spawning for active simulation scopes

## Cascading Generation

World generation should support cascading expansion.

A parent world or region summary should provide constraints and context for generating child regions, settlements, factions, NPCs, memories, and behaviors. Each expansion step should be validated before it is accepted.

Example progression:

```text
World overview
  → Major regions
    → Regional settlements and landmarks
      → Local factions
        → NPCs and relationships
          → Memories, rumors, secrets
            → Validated behavior metadata
              → Selective spawning into live OTP processes
```

The generator should not need to generate everything at once. It should be able to expand one scope at a time.

## Blueprint Tree

Large worlds should eventually be represented as a hierarchy of generated scopes.

Example conceptual shape:

```elixir
%{
  id: "world_ashen_realms",
  type: :world,
  name: "The Ashen Realms",
  summary: "...",
  children: [
    %{
      id: "region_salt_coast",
      type: :region,
      parent_id: "world_ashen_realms",
      name: "The Salt Coast",
      summary: "...",
      children: [
        %{
          id: "settlement_greyharbor",
          type: :settlement,
          parent_id: "region_salt_coast",
          name: "Greyharbor",
          summary: "..."
        }
      ]
    }
  ]
}
```

The early implementation may use simpler flat maps, but long-term architecture should preserve the ability to move toward scoped, hierarchical blueprints.

## Generate Broadly, Spawn Selectively

Do not assume the entire generated world should be spawned as live OTP processes immediately.

Large parts of the world may exist as:

* Inert blueprint data
* Summaries
* Persisted records
* Known but inactive scopes
* Unexpanded child scopes
* Generated but unspawned entities

Only the active simulation scope needs to be live.

Example:

```text
Generated world:
  12 regions
  40 settlements
  300 known NPCs
  60 factions

Live simulation:
  current settlement
  nearby NPCs
  immediately relevant factions
  active events
```

When the player travels, asks about a distant region, or triggers a relevant event, the system can expand, validate, and spawn that scope as needed.

## Summaries as Context

At large scale, the system cannot feed the entire world into every generation request. Each generated scope should have a compact summary.

A region summary might include:

```elixir
%{
  id: "region_salt_coast",
  name: "The Salt Coast",
  summary: "A storm-battered coastal region dominated by smugglers, lighthouse cults, and failing imperial ports.",
  themes: [:smuggling, :storm_worship, :imperial_decline],
  major_factions: ["faction_tidebound_church", "faction_blackwake_smugglers"],
  unresolved_conflicts: [
    "The church controls lighthouse access.",
    "Smugglers are hiding refugees from imperial tax collectors."
  ]
}
```

Child generation should use parent summaries, sibling constraints, existing IDs, and known facts rather than the full raw world state.

## Stable IDs and References

Generated scopes should use stable string IDs across generation layers.

Preserve:

* Stable world IDs
* Stable region IDs
* Stable settlement IDs
* Stable faction IDs
* Stable NPC IDs
* Parent-child relationships
* Cross-scope references
* Relationship references
* Location references
* Memory references
* Behavior target references

Avoid dynamically generated atoms. Generated IDs should remain strings.

## Validation at Every Layer

Each generation step should validate its output before accepting it into the world blueprint.

Validation should check:

* Required fields exist
* IDs are unique within the relevant scope
* References point to known or allowed targets
* Parent-child relationships are valid
* NPC locations are valid
* Relationships reference valid entities
* Starter memories have valid content and type
* Behavior metadata uses supported triggers and actions
* Generated content does not require spawning unsafe or unsupported entities
* Child scopes respect parent constraints

Invalid generated content should return structured errors rather than crashing.

## Lazy Expansion

The world should be able to start broad and become detailed only where needed.

Initial generation may include:

* World overview
* Major regions
* Starter region
* Starter settlement
* Starter NPCs
* Starter factions
* Starter memories
* Starter behavior metadata

Later expansion may occur when:

* The player travels to a new region
* The player asks about a distant place
* A faction action references another scope
* A quest or event requires more detail
* The simulation needs a previously inactive area to become active

This allows the world to feel large without requiring the entire world to be generated, validated, spawned, and simulated immediately.

## Relationship to OTP Processes

Generated scopes and live OTP processes are separate concepts.

A generated NPC in an inactive region may exist only as blueprint data. When that NPC becomes relevant, the system may hydrate or spawn it as a live entity process.

Elixir should decide:

* Which generated scopes are active
* Which entities should be spawned
* When inactive content should be expanded
* When live entities should be stopped, persisted, or summarized
* How generated data becomes simulation state

## Future Public API Direction

The public generator API may eventually grow toward functions like:

```elixir
Procession.Generator.generate_world(prompt, opts)
Procession.Generator.expand(blueprint, target_id, opts)
Procession.Generator.validate_blueprint(blueprint)
Procession.Generator.spawn_scope(blueprint, scope)
```

The exact API can evolve, but the architecture should preserve these concepts:

* Generate
* Expand
* Validate
* Spawn
* Inspect
* Persist later
* Hydrate later

## Guiding Principle

Procession world generation should be hierarchical and cascading: generate broad world structure first, then expand regions, settlements, factions, NPCs, memories, and behaviors in separate validated passes, using parent summaries and existing constraints so large worlds can emerge without requiring one massive generation request or one fully spawned simulation.
