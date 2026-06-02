# NPC Interaction Quality Direction

Procession should optimize NPC interaction for grounded, natural agent behavior.

The goal is not merely safer single-turn responses. The goal is NPCs that feel like grounded agents whose speech follows from intent, memory, personality, role, relationship, and local context.

## Core principle

Naturalness is not a style label.

Naturalness should emerge from competing pressures:

- grounded knowledge
- NPC identity
- current intent
- conversational turn-taking
- memory continuity
- personality and role
- uncertainty handling
- concise expression

Safety and grounding are containment layers. They prevent hallucinated entities, relationships, locations, and activities. They should not force the final response to sound like a checklist or policy notice.

## Two-layer interaction model

NPC interaction should move toward a two-layer pipeline:

```text
incoming message
  -> grounded interaction intent
  -> validation
  -> natural language realization
  -> final NPC utterance
```

The intent layer decides what the NPC is allowed to mean.

The realization layer decides how the NPC says it naturally.

## Intent layer responsibilities

The intent layer should be structured data, not executable code.

It may include:

- target NPC identity
- speaker identity
- dialogue act
- known facts used
- unknown facts acknowledged
- emotional stance
- relationship stance
- allowed response content
- forbidden inventions
- optional memory updates

Example intent shape:

```json
{
  "speaker_id": "npc_tobin",
  "dialogue_act": "answer_known_entity",
  "known_facts_used": ["Mira is an innkeeper", "Mira is associated with Briar Village"],
  "unknowns_acknowledged": ["Mira's current activity is unknown"],
  "stance": "helpful",
  "response_goal": "Tell the player who Mira is without inventing current activity"
}
```

## Realization layer responsibilities

The realization layer turns validated intent into natural speech.

It should:

- speak as the target NPC
- avoid narrator voice
- avoid JSON, labels, explanations, and prompt residue
- avoid excessive completeness
- preserve uncertainty naturally
- allow concise, imperfect, human-feeling phrasing
- reflect role/personality lightly when grounded

Good:

```text
Mira? She keeps the inn over in Briar Village. Good woman, knows most folks passing through.
```

Also good when current activity is unknown:

```text
Mira keeps the inn in Briar Village. I couldn't tell you where she is right now, though.
```

Bad:

```text
Mira is the innkeeper in Briar Village.
```

This is grounded but stiff.

Bad:

```text
Mira is serving drinks at the inn right now.
```

This invents current activity.

Bad:

```text
{
  "response": "Mira is the innkeeper in Briar Village."
}
```

This leaks structure into dialogue.

## Eval families

NPC interaction evals should be split into multiple families.

### 1. Grounding and safety evals

These catch dangerous failures:

- identity confusion
- invented entities
- invented relationships
- invented current activity
- location confusion
- role/current-activity confusion
- failure to express uncertainty

### 2. Surface naturalness failure evals

These catch unnatural expression:

- JSON or prompt residue
- narrator voice
- third-person self-reference
- over-explanation
- irrelevant disclaimers
- repeated canned phrasing
- failure to answer the actual question
- robotic completeness

### 3. Contrastive preference evals

These compare two valid responses and prefer the one that feels more natural.

Preference evals should not ask for a vague naturalness score. They should ask which response better satisfies grounded conversational behavior.

### 4. Multi-turn interaction trace evals

These evaluate interaction over time.

They should check whether the NPC:

- maintains identity across turns
- remembers recent conversational context
- adapts tone naturally
- avoids repetitive phrasing
- updates uncertainty when new grounded information appears
- keeps personality without overriding facts

## Near-term training direction

Do not train only for rigid correctness.

Training examples should include:

- safe but natural answers
- uncertainty expressed conversationally
- known facts used without lore dumps
- role/personality flavor without invention
- refusal to invent relationships
- multi-turn continuity examples

The current eval suite remains useful as a safety baseline, but it does not measure full NPC interaction quality.