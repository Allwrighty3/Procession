# Phase 17 Grounded Dialogue Acceptance

Phase 17 acceptance requires more than fake-adapter tests. Grounded NPC dialogue must be exercised through a real local AI run so remaining failure modes are visible before moving into the `npc_interaction` skill/training phase.

This document records the first human acceptance script for grounded dialogue.

## Local model

- Model: `llama3.2:1b`
- Adapter: `Procession.AI.Ollama`
- Demo entry point:

```elixir
Procession.CLI.play_ai("a quiet frontier town", model: "llama3.2:1b")
```

## Acceptance script

Run these commands in the AI-enabled CLI.

- [ ] `talk to Tobin: Who is Mira?`
- [ ] `grounded talk to Tobin: Who is Mira?`
- [ ] `grounded talk to Tobin: Where is Mira?`
- [ ] `grounded talk to Tobin: What is Mira's job?`
- [ ] `grounded talk to Mira: Who is Tobin?`
- [ ] `grounded talk to Tobin: Who is Elandra?`

## Expected behavior

Grounded dialogue should improve over normal dialogue by using authoritative context.

The model does not need to be perfect in Phase 17, but the acceptance run should reveal whether it:

- [ ] Preserves target NPC identity.
- [ ] Uses known entity facts when present.
- [ ] Avoids inventing facts outside the grounded context.
- [ ] Expresses uncertainty for unknown facts.
- [ ] Produces responses short enough for CLI play.
- [ ] Leaves entity state, memory, behavior metadata, and world state unchanged.

## Observed baseline result

### Normal dialogue

Command:

```text
talk to Tobin: Who is Mira?
```

Observed result:

```text
Tobin says: "Ah, a traveler, I see," Tobin says with a fidgety smile, his nervousness evident despite himself. "You're looking for Mira, I reckon? She's that mysterious healer who's been passing through these parts lately... said to possess knowledge of the ancient ways."
```

Notes:

- Invented unsupported facts.
- Changed Mira into a mysterious healer.
- Did not stay grounded in authoritative known entity facts.

### Grounded dialogue

Command:

```text
grounded talk to Tobin: who is mira?
```

Observed result:

```text
"Tobin here," I say with a nervous smile, trying to compose myself amidst the bustling commotion of the crossroads. "I'm Mira, innkeeper of this humble establishment." My eyes dart around the room, ensuring no one is listening in on our conversation.
```

Notes:

- Grounded path clearly produced a different response.
- The model saw Mira’s authoritative role as innkeeper.
- The model failed target identity preservation by claiming Tobin was Mira.
- This confirms that context alone is not enough for reliable `npc_interaction`.
- Phase 18 should address this through a task-specific NPC interaction skill boundary, validation, evals, dataset creation, and training.

## Phase 17 conclusion

Phase 17 should not attempt to solve all NPC interaction quality through prompt tweaks.

Phase 17 is acceptable when:

- [ ] Grounded dialogue context exists.
- [ ] Grounded prompt construction exists.
- [ ] Grounded dialogue is wired behind an explicit opt-in path.
- [ ] Grounded dialogue is visible through command/CLI usage.
- [ ] Real local Ollama behavior has been observed.
- [ ] Known failure modes are documented.
- [ ] Remaining consistency/quality work is assigned to Phase 18.

## Known failure carried into Phase 18

Primary failure:

```text
Target identity confusion.
```

Example:

```text
Tobin claimed to be Mira after receiving grounded context that included Mira as a known active entity.
```

Phase 18 should treat this as the first `npc_interaction` training and validation target.
