# NPC Interaction Training Export

## Purpose

This document explains how to regenerate the local NPC interaction training export.

The export is derived from the curated NPC interaction training corpus:

```text
priv/training/npc_interaction_examples.jsonl
```

The export is written to:

```text
priv/training/exports/npc_interaction_training_export.jsonl
```

## Regenerate the export

From the project root, run:

```bash
mix procession.training.npc_interaction.export
```

Expected output:

```text
Exported 25 NPC interaction training examples.
Output: priv/training/exports/npc_interaction_training_export.jsonl
```

## Custom output path

To write the export somewhere else:

```bash
mix procession.training.npc_interaction.export --output /tmp/npc_interaction_training_export.jsonl
```

## Export shape

Each exported JSONL line has this shape:

```json
{
  "id": "example_id",
  "task": "npc_interaction",
  "input": {
    "context": {}
  },
  "output": {
    "expected_response": "string"
  },
  "metadata": {
    "rejected_responses": [],
    "failure_tags": [],
    "notes": "string",
    "non_authoritative": true
  }
}
```

## Reproducibility

The export sorts examples by `id` before writing output.

This makes the generated file stable as long as the source corpus contents are unchanged.

## Non-authoritative status

The export is training data only.

It must not be imported into runtime entity state, entity memory, behavior metadata, world state, active scopes, or canonical lore.

The `"non_authoritative": true` metadata flag is included as an explicit reminder that the exported examples teach bounded response behavior, not world truth.

## Validation

Before exporting, the Mix task loads the default corpus through the training example loader.

The loader validates required fields and JSONL structure before the export is written.

To validate without exporting, run:

```bash
mix procession.training.npc_interaction.validate
```