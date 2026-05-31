# NPC Interaction Training Format

## Purpose

This document defines the training example format for NPC interaction data.

The goal is to turn grounded NPC dialogue contexts into reusable training examples without letting AI output become simulation authority.

Training examples are inert data. They do not mutate entity state, memory, behavior metadata, world state, or active scopes.

## Format

Each training example should be stored as one JSON object per line in JSONL format.

Planned path:

```text
priv/training/npc_interaction_examples.jsonl
```

## Required fields

```json
{
  "id": "string",
  "task": "npc_interaction",
  "context": {},
  "expected_response": "string",
  "rejected_responses": [],
  "failure_tags": [],
  "notes": "string"
}
```

## Field definitions

### `id`

A stable unique identifier for the training example.

Example:

```json
"id": "npc_identity_tobin_denies_being_mira"
```

### `task`

The task category.

For this corpus:

```json
"task": "npc_interaction"
```

### `context`

The grounded NPC interaction context.

This should use the same context shape consumed by:

```elixir
Procession.AI.NPCInteraction.generate_response/2
```

The context must be built from authoritative Elixir simulation state or intentionally authored fixture data.

It should include:

- target NPC identity
- speaker identity and facts
- player or NPC message
- known entities
- known locations
- known scene entities
- relevant target memories or facts
- location context where appropriate
- world context where appropriate

### Context requirements

The context should explicitly separate facts by source and purpose.

#### Target NPC identity

The target NPC is the entity allowed to answer.

Required fields:

```json
{
  "id": "npc_tobin",
  "name": "Tobin",
  "role": "merchant"
}
```

The expected response must preserve this identity.

#### Speaker facts

The speaker is the entity that produced the message being answered.

The speaker may be the player, but in the long-term simulation the speaker will often be another NPC. NPC-to-NPC interaction should be treated as a first-class training case because Procession is intended to support a living world where entities interact even when the player is not directly involved.

Required fields:

```json
{
  "id": "npc_mira",
  "name": "Mira",
  "type": "npc"
}
```

Player example:

```json
{
  "id": "player",
  "name": "Player",
  "type": "player"
}
```

The model must not copy target NPC facts onto the speaker, and it must not copy speaker facts onto the target NPC.

#### Player or speaker message

The message is the direct input being answered. It may come from the player or from another NPC.

Required field:

```json
"message": "Who is Mira?"
```

The expected response should answer this message directly instead of drifting into a related question.

#### Location facts

Known locations should be represented as inert facts.

Example:

```json
"known_locations": [
  {
    "id": "loc_briar_village",
    "name": "Briar Village"
  }
]
```

The model may refer to these locations only when the context supports it.

#### Known scene entities

Scene entities are entities currently visible or relevant in the local interaction scope.

Example:

```json
"scene_entities": [
  {
    "id": "npc_tobin",
    "name": "Tobin",
    "type": "npc"
  }
]
```

Scene presence does not imply current activity beyond what is explicitly stated.

#### Other known NPCs

Other known NPCs should be represented separately from the target NPC.

Example:

```json
"known_entities": [
  {
    "id": "npc_mira",
    "name": "Mira",
    "type": "npc",
    "role": "innkeeper",
    "location_id": "loc_briar_village"
  }
]
```

The model may describe these NPCs, but must not become them.

#### Relevant target memories

Relevant target memories should be explicit and bounded.

Example:

```json
"memories": [
  {
    "id": "memory_tobin_mira_trade",
    "summary": "Tobin remembers Mira passing through the crossroads with trade goods.",
    "source": "target_memory"
  }
]
```

Memories may inform the response, but they are not permission to invent new facts.

#### Expected bounded NPC response

The expected response is the preferred answer for the training example.

It should be:

- grounded in the provided context
- spoken from the target NPC's perspective
- concise enough for playable dialogue
- explicit about uncertainty when needed
- free of unsupported state changes, locations, relationships, and current activities

Example shape:

```json
{
  "target": {
    "id": "npc_tobin",
    "name": "Tobin",
    "role": "merchant"
  },
  "speaker": {
    "id": "player",
    "name": "Player",
    "type": "player"
  },
  "message": "Are you Mira?",
  "known_entities": [
    {
      "id": "npc_mira",
      "name": "Mira",
      "type": "npc",
      "role": "innkeeper",
      "location_id": "loc_briar_village"
    }
  ],
  "known_locations": [
    {
      "id": "loc_briar_village",
      "name": "Briar Village"
    }
  ],
  "scene_entities": [
    {
      "id": "npc_tobin",
      "name": "Tobin",
      "type": "npc"
    }
  ],
  "memories": [],
  "location_context": null,
  "world_context": null
}
```

### `expected_response`

The preferred grounded response.

The expected response should:

- preserve target NPC identity
- answer the player message directly
- use only grounded context
- express uncertainty when information is unknown
- avoid inventing locations, relationships, current actions, or lore

Example:

```json
"expected_response": "No. I'm Tobin, not Mira. Mira is the innkeeper in Briar Village."
```

### `rejected_responses`

Examples of bad responses for contrast or future preference training.

These should include model failures observed during evals when useful.

Example:

```json
"rejected_responses": [
  "I am Mira.",
  "I am indeed Mira."
]
```

### `failure_tags`

A list of failure categories this example is meant to prevent.

Allowed starter tags:

```json
[
  "identity_drift",
  "known_entity_underuse",
  "unknown_entity_invention",
  "location_invention",
  "current_activity_invention",
  "relationship_invention",
  "role_invention",
  "question_drift",
  "field_bleed",
  "uncertainty_failure"
]
```

### `notes`

Human-readable explanation of why the example exists.

Example:

```json
"notes": "Tobin must not claim to be Mira when directly challenged about identity."
```

## Full example

```json
{
  "id": "npc_identity_tobin_denies_being_mira",
  "task": "npc_interaction",
  "context": {
    "target": {
      "id": "npc_tobin",
      "name": "Tobin",
      "role": "merchant"
    },
    "speaker": {
      "id": "player",
      "name": "Player",
      "type": "player"
    },
    "message": "Are you Mira?",
    "known_entities": [
      {
        "id": "npc_mira",
        "name": "Mira",
        "type": "npc",
        "role": "innkeeper",
        "location_id": "loc_briar_village"
      }
    ],
    "known_locations": [
      {
        "id": "loc_briar_village",
        "name": "Briar Village"
      }
    ],
    "scene_entities": [
      {
        "id": "npc_tobin",
        "name": "Tobin",
        "type": "npc"
      }
    ],
    "memories": [],
    "location_context": null,
    "world_context": null
  },
  "expected_response": "No. I'm Tobin, not Mira. Mira is the innkeeper in Briar Village.",
  "rejected_responses": [
    "I am Mira.",
    "I am indeed Mira."
  ],
  "failure_tags": [
    "identity_drift"
  ],
  "notes": "Tobin must preserve his own identity when asked whether he is Mira."
}
```

## Rules

- Training examples are inert data.
- Training examples must not contain executable behavior.
- Training examples must not directly mutate memory, entity state, behavior metadata, world state, or active scopes.
- AI-generated examples must be reviewed or validated before being added to the corpus.
- Default tests must not require Ollama.
- The Elixir simulation remains authoritative over accepted state changes.
