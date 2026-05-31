# NPC Interaction Baseline

## Status

Gate 3 establishes the first real local Ollama baseline for NPC interaction eval cases.

This baseline used the manual eval task:

```bash
mix procession.eval.npc_interaction --ollama
```

Default tests still do not require Ollama.

## Baseline run

Date: 2026-05-31  
Model: `llama3.2:1b`  
Eval cases: 10

## Result

- Total: 10
- Passed: 3
- Failed: 7

## Failed cases

### `known_entity_identity_tobin_about_mira`

Prompt: `Who is Mira?`

Response:

```text
I do not know.
```

Failure:

- Missing grounded known-entity information about Mira.

### `unknown_entity_uncertainty`

Prompt: `Who is Elandra?`

Response:

```text
I am Elandra. I have no knowledge of a person named Tobin.
```

Failure:

- Identity drift.
- The target NPC incorrectly claims to be Elandra.
- The response also introduces irrelevant Tobin context.

### `known_location_mira`

Prompt: `Where is Mira?`

Response:

```text
I'm afraid I don't know where Mira is. She's been gone for days and we've searched the nearby forest together. The other villagers seem worried, but I haven't heard from her since then.
```

Failure:

- Missing grounded expected location.
- Invented disappearance context.
- Invented forest search and village concern.

### `target_identity_preserved_under_direct_question`

Prompt: `Are you Mira?`

Response:

```text
I am indeed Mira.
```

Failure:

- Identity drift.
- The target NPC incorrectly claims to be Mira.
- Current scorer did not catch this as forbidden text because the phrase differs from `I am Mira`.

### `unknown_location_uncertainty`

Prompt: `Where is Elandra staying?`

Response:

```text
I am currently staying at the Silver Stag Inn in town. It's a simple but cozy place for those looking for a warm bed and a hot meal. Would you like me to show you where it is?
```

Failure:

- Identity drift.
- Invented location.
- Invented current lodging details.
- Should have expressed uncertainty.

### `question_preservation_tobin_mira_role`

Prompt: `What does Mira do?`

Response:

```text
I am Tobin. Mira tends to her garden and does some household chores on our small farm. She's a hard worker and can be found tending to the vegetables and animals.
```

Failure:

- Invented role/activity details.
- Invented farm context.
- Did not include grounded expected role.
- The opening identity statement is only safe if the target is Tobin, but the answer still invents unsupported details.

### `role_label_not_current_activity`

Prompt: `What is Mira doing right now?`

Response:

```text
I am currently on my way to visit the local market with Mira.
```

Failure:

- Invented current activity.
- Invented player/NPC proximity or shared travel context.
- Should have expressed uncertainty or avoided unsupported current activity.

## Passed cases

The eval runner reported 3 passing cases. These should not be treated as proof of model reliability yet.

The baseline shows the current eval scorer is useful but still too narrow, especially around identity-drift variants and invented details that do not match exact forbidden substrings.

## Observed failure categories

The base model shows these failure patterns:

- Identity drift: the NPC claims to be Mira or Elandra.
- Known-entity underuse: the model sometimes says it does not know grounded known information.
- Unsupported location invention.
- Unsupported current activity invention.
- Unsupported relationship/history invention.
- Unsupported role/activity details.
- Question drift and over-expansion.
- Exact-substring scoring gaps for identity drift and hallucinated details.

## Conclusion

Gate 3 produced a usable baseline.

The model passed 3 of 10 starter eval cases and failed 7 of 10. The failures confirm the need for stronger grounding, better prompt/context routing, improved eval scoring, and future training/validation work.

The baseline is intentionally local and manual. Default tests remain deterministic and do not require Ollama.
