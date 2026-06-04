# Model Training Roadmap

This roadmap tracks Procession's task-specific model development work.

The main project roadmap lives in `docs/ROADMAP.md`. This file focuses only on AI/model-training direction, dataset evolution, evaluation strategy, local training experiments, and how trained models should fit into the Elixir/OTP simulation architecture.

This document should provide enough context for a future assistant or developer to understand the current model-training state and direction even when read in isolation.

---

## Current State Summary

Procession is an Elixir/OTP-first single-player RPG simulation.

Elixir owns:

* truth
* canon
* entity state
* memory
* relationship values
* world facts
* simulation state
* validation
* deterministic fallbacks
* whether model output is accepted or rejected

AI owns:

* phrasing
* rhythm
* voice
* tone
* subjective attitude
* natural expression
* emotional flavor
* candidate dialogue text

AI-generated text/data is untrusted until validated.

The current NPC dialogue direction is:

1. Elixir gathers grounded context.
2. Elixir builds or validates a response intent.
3. Elixir creates a deterministic fallback.
4. A model proposes natural in-character expression.
5. Elixir cleans and validates the candidate.
6. The candidate is used only if safe; otherwise fallback is used.

The goal is not for dialogue to feel deterministic forever. Deterministic fallback is scaffolding. The player-facing ideal is dynamic, natural, in-character dialogue that remains bounded by Elixir-owned truth.

The current training work is focused on supervised NPC dialogue expression, not autonomous canon generation.

---

## Repositories and Local Paths

Main repo:

```text
GitHub: Allwrighty3/Procession
Local path: ~/projects/Procession
```

Training/lab repo:

```text
Local path: ~/procession-ai-training
Currently not tracked by git
```

Training artifacts and model outputs should remain outside the runtime assumptions of the main Procession app unless explicitly documented.

Normal Procession development and tests must not require local training tooling, ROCm, Ollama, or model artifacts.

---

## Architecture Guardrails

### AI is central, but not sovereign

AI is central to Procession's purpose. The project should not minimize AI. It should contain and structure AI so that its creativity can drive dynamic dialogue, world expansion, rumors, faction tension, behavior proposals, and cascading content generation without turning the simulation into inconsistent nonsense.

Elixir/OTP is the authoritative scaffold.

AI may propose expressive or generative content. Elixir decides what is accepted.

### Model output must not secretly write canon

A model response may express:

* suspicion
* affection
* irritation
* humor
* grief
* curiosity
* evasion
* confidence
* uncertainty
* follow-up questions
* subjective opinions

A model response must not invent objective facts such as:

* identity
* role
* job
* family relationship
* location
* current activity
* history
* major events
* world facts
* relationship values
* memories
* entity state

Questions are generally safer than assertions when adding flavor around unknown people or events.

Example:

```text
Unsafe assertion:
She owes me money.

Safer flavor question:
She looking for money?
```

### The model expresses selected state; Elixir selects state

The model should not decide that Mira becomes hostile when Tobin is mentioned.

Elixir should detect the topic, relationship, memory, or trigger and supply expression metadata such as:

```text
emotional_state: wounded
delivery_style: sharp
conversational_move: challenge_premise
relationship_stance: guarded
situation: tobin_family_question
```

The model then expresses that selected state naturally.

Runtime split:

```text
Player input
-> Elixir parses intent/entities/topic
-> Elixir checks facts, relationships, memories, and triggers
-> Elixir selects expression metadata
-> Elixir creates deterministic fallback
-> Model proposes natural expression
-> Elixir cleans and validates candidate
-> Candidate or fallback is displayed
```

---

## Completed / Historical Model Phases

### QE1 / QE2: Raw NPC Interaction Experiments

Goal:

Discover failure modes in direct NPC interaction generation.

Result:

Useful for learning, but too prone to:

* identity swaps
* role confusion
* invented facts
* invented relationships
* unsupported world lore
* stiff answers
* verbose over-explanation
* NPCs answering as the wrong character

Status:

```text
Completed as exploratory work.
Not suitable as a runtime architecture.
```

---

### QE3: Safe Natural Expression

Input:

```text
validated intent + deterministic fallback
```

Goal:

Teach the model to rewrite safe fallback text into more natural NPC dialogue without changing meaning.

Example:

```text
Fallback:
Mira is the innkeeper in Briar Village.

Model:
Mira? She keeps the inn over in Briar Village.
```

Result:

QE3 successfully demonstrated that a small local model can learn:

* validated fallback -> natural line
* safer rewriting
* less rigid phrasing
* basic dialogue naturalization

Status:

```text
Completed.
Useful foundation.
Not enough personality control.
```

---

### QE4: Voice-Aware Expression

Input:

```text
validated intent + fallback + voice_profile
```

Goal:

Teach the model that the same truth can be expressed differently by different speakers or voice profiles.

Example:

```text
Polite Mira:
No, Tobin isn't family. He's the merchant out by the crossroads.

Haughty Mira:
Tobin? My brother? Not a chance.
```

Result:

QE4 helped move from generic natural expression toward speaker-specific expression.

Status:

```text
Completed as an intermediate experiment.
Useful, but too limited without emotion and relationship context.
```

---

### QE4b: Emotional Amplitude / Stronger Style

Input:

```text
validated intent + fallback + voice_profile + emotional_state
```

Goal:

Teach stronger emotional range without inventing canon.

Examples:

```text
Cold:
No.

Contemptuous:
Tobin? That roadside fool? Not a chance.

Protective:
No. But if you're looking to cause Tobin trouble, choose your next words carefully.

Wounded:
No. Family is not a word I throw around.
```

Observed strengths:

* Model learned stronger emotional starts.
* Some outputs matched expected answers exactly.
* Some outputs showed useful tone variation.
* Some outputs produced good sharp first sentences.

Observed weaknesses:

* Some expected answers were too unnatural or test-like.
* The model often over-explained.
* The model sometimes added unsafe trailing hallucinations.
* The model avoided natural follow-up questions too often.
* Some outputs sounded like debug-friendly lore summaries rather than natural speech.
* Emotional state alone was too muddy.
* "Blunt" was incorrectly treated like an emotion instead of a delivery style.
* Some safe generated outputs were better dialogue than their expected targets.
* Good openings did not guarantee safe full outputs.

Important lesson:

```text
QE4b showed that the issue is not only model drift.
The dataset targets themselves need better natural-dialogue taste.
```

Status:

```text
Completed as a useful diagnostic phase.
Do not treat QE4b expected outputs as final ideal dialogue targets.
Use QE4b feedback to design QE5.
```

---

## Current Focus

### QE5: Natural Conversation Shape

Current model-training focus:

```text
QE5: Natural conversation shape
```

Input:

```text
intent + fallback + voice_profile + emotional_state + delivery_style + conversational_move
```

Goal:

Teach the model that good NPC dialogue can be:

* short
* indirect
* partial
* question-driven
* evasive
* suspicious
* warm
* hostile
* sharp
* rambling
* playful
* wounded
* professionally controlled
* naturally incomplete when appropriate

QE5 should correct the most important QE4b issue:

```text
Expected answers should sound like character dialogue, not validator reports.
```

### Key QE5 Concepts

#### Emotional state

The character's internal or situational feeling.

Examples:

```text
cold
wounded
protective
furious
on_edge
tired
excited
hostile
professional
curious
numb
```

#### Delivery style

The shape or manner of the response.

Examples:

```text
terse
plain
sharp
warm
controlled
rambling
eager
formal
evasive
```

Important:

```text
Terse/blunt is not an emotion.
```

The line:

```text
No.
```

could express:

* coldness
* suspicion
* exhaustion
* anger
* professionalism
* numbness
* fear
* dissociation

The metadata should explain why the line is short.

#### Conversational move

What the response is doing in conversation.

Examples:

```text
answer_only
answer_and_warn
answer_and_redirect
answer_and_question
ask_followup
challenge_premise
deflect_with_humor
evade
refuse
press_for_reason
```

This is how the dataset gives the model permission to ask natural questions.

Example:

```text
Fallback:
I do not know Elandra.

on_edge + terse + ask_followup:
Elandra? She looking for money?

tired + rambling + ask_followup:
Elandra? Someone else trying to collect on a debt?

professional + terse + answer_only:
No.
```

### QE5 Design Rules

* Expected dialogue should sound like a character speaking, not a fact validator reporting success.
* Use the minimum amount of grounded fact needed for the moment.
* Do not restate names unless it sounds natural, useful, hostile, confused, or emphatic.
* Pronouns are allowed when the referent is obvious.
* Follow-up questions are allowed and encouraged when they reveal personality or keep conversation alive.
* Short answers are valid outputs.
* "No." can be emotionally correct.
* Emotional state and delivery style are separate.
* A response may be safe and useful even if it does not restate every validated fact.
* The model may express suspicion, irritation, affection, humor, exhaustion, or curiosity.
* The model must not invent objective world facts.
* Questions are safer than assertions when adding flavor around unknown people or events.

### QE5 Starter Examples

```text
Cold + terse + answer_only:
No.

Wounded + plain + answer_only:
No. I don't use the word family lightly.

Protective + sharp + answer_and_warn:
No. But if you're looking to cause Tobin trouble, choose your next words carefully.

Furious + terse + challenge_premise:
Do I look like Tobin to you?

Angry + sharp + answer_only:
How should I know? I don't follow her around.

Hostile + controlled + answer_and_challenge:
Never heard of her. State your business.

On edge + terse + ask_followup:
Elandra? She looking for money?

Tired + rambling + ask_followup:
Elandra? Someone else trying to collect on a debt?

Excited + eager + ask_followup:
I don't know! Is she a knight? Does she have a sword?
```

### QE5 Completion Criteria

* [ ] Add QE5 training examples focused on natural conversation shape.
* [ ] Include `delivery_style`.
* [ ] Include `conversational_move`.
* [ ] Keep `emotional_state`.
* [ ] Include examples where short answers are ideal.
* [ ] Include examples where pronouns are more natural than repeated names.
* [ ] Include examples where a follow-up question is the best response.
* [ ] Include examples where the NPC answers only what was asked.
* [ ] Include examples where relevant facts are intentionally omitted because they would sound unnatural.
* [ ] Include examples where the same fallback is expressed differently based on emotion/style/move.
* [ ] Avoid turning every expected output into a full explanation.
* [ ] Add loader/export tests if the file lives in the main repo.
* [ ] Update prompt construction to include delivery style and conversational move.
* [ ] Make missing fields default safely for older examples.
* [ ] Train a QE5 LoRA locally.
* [ ] Run smoke generation against the specific QE5 cases.
* [ ] Review generated outputs manually.
* [ ] Decide whether QE5 improves naturalness over QE4b.

### QE5 Acceptance Questions

When reviewing QE5 output, ask:

* Did it preserve the validated intent?
* Did it avoid inventing canon?
* Did it respect delivery style?
* Did it respect conversational move?
* Did it ask a question when appropriate?
* Did it avoid unnecessary exposition?
* Did it sound like a person instead of a lore clerk?
* Did it stop cleanly?
* Would this be acceptable player-facing dialogue after validation?

Do not judge QE5 by exact match only.

Suggested manual grading fields:

```text
canon_safe: yes/no
intent_preserved: yes/no/partial
tone_fit: yes/no/partial
delivery_fit: yes/no/partial
conversation_flow: yes/no/partial
naturalness: yes/no/partial
needs_cleanup: yes/no
accept_player_facing: yes/no
notes
```

### QE5 Result

QE5 is considered a successful first pass.

It trained natural conversation shape using:

- `emotional_state`
- `delivery_style`
- `conversational_move`

Observed result:

- Raw outputs often had the correct first line or phrase.
- Some raw outputs continued with unnecessary or unsafe tails.
- `ResponseCandidateCleaner` now trims common drift while preserving rhetorical question chains and expressive short-question setups.
- Remaining issues around verbosity, long question chains, and expressive continuation should be handled through future response-length metadata, relationship-aware expression, and situation-aware context rather than over-tightening the cleaner.

QE5 is good enough to move forward to QE6.

---

## Near-Term Model Phases

### QE6: Relationship-Aware Expression

Input:

```text
intent + fallback + voice_profile + emotional_state + delivery_style + conversational_move + relationship_stance
```

Goal:

Same speaker and same truth, but different expression depending on relationship to the listener or subject.

Examples:

```text
Mira toward a paying guest:
No. I run the inn.

Mira toward a child:
No, dear. Tobin isn't my brother.

Mira toward someone she distrusts:
No. Why are you asking?

Mira when Tobin is the subject:
Don't use that word lightly around me.
```

QE6 teaches relationship-aware expression, but Elixir still supplies the relationship stance.

The model must not invent:

* who likes whom
* who hates whom
* who is family
* who owes money
* who betrayed whom
* who helped whom

Completion criteria:

* [ ] Add relationship-aware examples.
* [ ] Include relationship to listener.
* [ ] Include relationship to subject where relevant.
* [ ] Include same fallback expressed differently for different listeners.
* [ ] Include same fallback expressed differently for different subject relationships.
* [ ] Keep relationship facts Elixir-owned.
* [ ] Train and evaluate relationship-conditioned output.
* [ ] Confirm model does not invent unsupported relationships.

### QE6b Result

QE6b improved some exact-row behavior but did not generalize well enough.

Observed holdout failures:

- New names and roles were sometimes dropped or malformed.
- The model mutated roles, such as turning healer/baker into “I keep the healer/bakery.”
- It overused suspicious phrasing like “Why are you asking about me?”
- It did not reliably express unfamiliar moods such as despondent, ashamed, or reluctant.
- It showed weaker behavior on unseen names/roles than on Mira/Tobin/Elandra examples.

Decision:

QE6 should not advance to QE7 yet.

Next step:

QE6c adds synthetic, non-authoritative relationship-expression examples with varied names, roles, moods, listener relationships, and subject relationships. The purpose is generalization, not new canon.

---

### QE7: Situation / Topic-Aware Expression

Input:

```text
intent + fallback + voice_profile + relationship_stance + emotional_state + delivery_style + conversational_move + current situation/topic
```

Goal:

Same speaker can shift expression when the immediate situation or sensitive topic changes.

Example:

```text
Normal public inn interaction:
Player: Do you have a room?
Mira: Of course. Need one bed or two?

Tobin family question:
Player: Is Tobin your brother?
Mira: No. Don't use that word lightly around me.

Player pushes the topic:
Player: Why not? What happened?
Mira: I said no.
```

Important:

QE7 trains expression for situationally selected state.

It does not train the model to decide the situation.

Elixir should decide the active topic/situation and expression metadata.

Completion criteria:

* [ ] Add examples with `situation` or `topic`.
* [ ] Include sensitive-topic shifts.
* [ ] Include public/private context differences.
* [ ] Include under-pressure responses.
* [ ] Include examples where the same NPC is friendly in one situation and hostile in another.
* [ ] Ensure Elixir-owned metadata selects the state.
* [ ] Ensure model only expresses supplied state.
* [ ] Avoid letting the model infer hidden trauma or secret relationships.

---

## Elixir Companion Phase: Situational State Selector

This is not primarily a model-training phase. It belongs to the Elixir simulation architecture.

Goal:

Elixir detects relevant entities, topics, relationships, memory markers, and personality triggers, then selects expression metadata for the model.

Example structure:

```elixir
%{
  character: :mira,
  default_expression: %{
    emotional_state: :friendly,
    delivery_style: :warm,
    conversational_move: :answer_and_question
  },
  triggers: [
    %{
      topic: :tobin_family_relationship,
      emotional_state: :wounded,
      delivery_style: :sharp,
      conversational_move: :challenge_premise,
      relationship_stance: :guarded
    }
  ]
}
```

Runtime example:

```text
Player asks whether Tobin is Mira's brother.
-> Elixir detects Tobin + family relationship question.
-> Elixir checks Mira's trigger metadata.
-> Elixir selects wounded/sharp/challenge_premise.
-> Model expresses the selected state.
-> Elixir validates the candidate.
```

Completion criteria:

* [ ] Define a small expression-context data shape.
* [ ] Define default expression metadata for a starter NPC.
* [ ] Define at least one topic/entity trigger.
* [ ] Detect a known trigger from player input or validated intent.
* [ ] Select emotional state, delivery style, conversational move, and relationship stance deterministically.
* [ ] Pass selected metadata into the response expression prompt.
* [ ] Add tests proving Mira can be friendly by default and hostile/wounded when Tobin is mentioned.
* [ ] Keep model output non-authoritative.
* [ ] Keep the selector simple and inspectable.

---

## Later Model Phases

### QE8: Memory-Aware Expression

Input:

```text
intent + fallback + voice_profile + relationship_stance + situation/topic + recent memories/conversation history
```

Goal:

NPCs respond based on recent interactions without inventing unsupported history.

Example:

```text
After the player helped Mira:
No, Tobin isn't family. Though after what you did for the inn, you're closer to family than most.

After the player insulted her:
No. And you are testing my patience again.
```

Important:

Memory content must be selected and supplied by Elixir.

The model may refer to supplied memory. It may not invent memory.

Completion criteria:

* [ ] Define what memory snippets are safe to provide.
* [ ] Include recent player interaction examples.
* [ ] Include positive and negative relationship memory examples.
* [ ] Include examples where memory changes tone but not canon.
* [ ] Validate that memory references are grounded.
* [ ] Reject outputs that invent unsupported prior events.

---

### QE9: Gradual Arc-Aware Personality Evolution

Goal:

Characters change slowly through repeated events, trust changes, betrayal, loyalty, gratitude, fear, injury, rivalry, or repeated exposure.

Example:

```text
Early:
Pirates? I don't trust pirates.

Later, after earned loyalty:
Say what you want about pirates. I know who Luffy is.
```

In Procession terms:

* personality development should be tracked by Elixir-owned state
* relationship changes should be explicit data
* character development summaries should be validated
* gradual change should be inspectable

Completion criteria:

* [ ] Define gradual development state.
* [ ] Track trust/fear/loyalty/resentment or similar relationship values.
* [ ] Add development summaries as validated data.
* [ ] Feed only relevant summaries into expression context.
* [ ] Train examples where the same character changes over repeated interactions.
* [ ] Ensure the model does not decide progression on its own.

---

### QE10: Epoch-Aware Personality Transformation

Goal:

Major life-changing events can create a new active personality epoch.

This covers drastic changes like a character being fundamentally different before and after a formative event.

Tracked data may include:

* previous personality epoch
* formative event
* active personality epoch
* suppressed traits
* new coping style
* re-emergence triggers

Example structure:

```text
Before loss:
combative, fierce, reckless, openly aggressive

After loss:
gentle, restrained, nurturing, avoids old violence

Under trigger:
old ferocity may re-emerge when chosen family is threatened
```

Important:

The model expresses the active epoch. It does not decide that an epoch transformation occurred.

Completion criteria:

* [ ] Define a personality epoch data shape.
* [ ] Define how a major world event changes active epoch.
* [ ] Define suppressed traits and re-emergence triggers.
* [ ] Add examples with before/after personality epochs.
* [ ] Add examples where old traits surface under a trigger.
* [ ] Validate that epoch references are supplied by Elixir-owned state.
* [ ] Prevent the model from inventing formative events.

---

## Candidate Cleanup and Validation Direction

The model may produce a good first sentence and unsafe trailing text.

Example pattern:

```text
Good:
No. But if you're looking to cause Tobin trouble, choose your next words carefully.

Bad tail:
He lives in the crossroads, and I keep the goods. Don
```

The pipeline should eventually be:

```text
raw model output
-> candidate cleaner
-> response validator
-> accept candidate or use fallback
```

Candidate cleaner may handle:

* speaker labels
* wrapping quotes
* extra whitespace
* dangling fragments
* repeated response prefixes
* unfinished final phrases
* obvious generation artifacts
* overly long continuations where a clean first sentence/prefix is available

Validator should handle:

* identity violations
* invented relationships
* invented jobs/roles
* invented locations
* invented current activities
* invented history
* unsupported memory references
* false canon assertions
* unsafe field bleed
* responses that rewrite the player question as fact

Cleaner should not decide canon truth.

Validator should not reject valid false-premise rejection just because dangerous words appear.

Valid:

```text
Tobin? My brother? Not a chance.
```

Invalid unless grounded:

```text
My brother Tobin sells goods by the crossroads.
```

---

## Evaluation Strategy

Exact match is useful but insufficient.

Manual grading should separate safety from quality.

Suggested fields:

```text
id
prompt/input summary
expected
generated
canon_safe
intent_preserved
tone_fit
delivery_fit
conversation_flow
naturalness
needs_cleanup
accept_player_facing
notes
```

A generated answer can be:

* safe but incomplete
* natural but too vague
* expressive but unsafe
* exact but unnatural
* better than expected
* valid only if trimmed
* rejected outright

Expected answers should also be graded. The expected answer is not automatically ideal.

QE4b lesson:

```text
Some expected answers were safe but unnatural.
Some generated answers were safer or more natural than expected.
Some generated answers had excellent starts but unsafe tails.
```

---

## Local Training Notes

Known local training environment:

```text
Desktop GPU:
AMD Radeon RX 6700 XT
12 GB dedicated VRAM

Current training environment:
Ubuntu/Linux with ROCm
Python virtual environment used for training
Training/lab path:
~/procession-ai-training
```

Training strategy:

* prefer local/free tooling
* do not train from scratch
* use LoRA/adapters
* keep experiments reproducible
* record exact commands
* keep model outputs out of the main repo unless intentionally documented
* keep Procession runtime independent from training dependencies

Current experiment family:

```text
SmolLM2 / small local causal LM experiments
LoRA-style fine-tuning
QE3, QE4, QE4b expression experiments completed locally
QE5 planned next
```

---

## Deferred Work

Do not do these yet unless the roadmap changes:

* [ ] Do not train autonomous behavior execution.
* [ ] Do not train AI to mutate memory.
* [ ] Do not train AI to mutate world state.
* [ ] Do not train AI to author executable behavior.
* [ ] Do not make trained models mandatory for Procession tests.
* [ ] Do not require Ollama or ROCm for normal Procession development.
* [ ] Do not start large-scale generated datasets until the small curated examples are clearly working.
* [ ] Do not train cascading world generation yet.
* [ ] Do not train faction planning yet.
* [ ] Do not train relationship progression yet.
* [ ] Do not train personality epoch changes until Elixir has a state model for them.

---

## Current Next Actions

Immediate recommended work:

* [ ] Create QE5 natural conversation-shape examples.
* [ ] Add `delivery_style`.
* [ ] Add `conversational_move`.
* [ ] Update prompt builder to include the new fields.
* [ ] Default missing fields safely for older examples.
* [ ] Add or update tests for QE5 example loading/export shape.
* [ ] Train QE5 locally.
* [ ] Run smoke generation.
* [ ] Manually grade expected and generated outputs.
* [ ] Use the results to decide whether to expand QE5 or adjust the prompt/data again.

After QE5:

* [ ] Add relationship-aware examples for QE6.
* [ ] Build the Elixir situational state selector.
* [ ] Add situation/topic-aware examples for QE7.
* [ ] Revisit candidate cleanup and validator improvements using real model failures.

---

## Core Principle

Procession's model-training work should make NPCs feel more alive without letting AI become the source of truth.

The model should eventually produce dynamic, varied, emotionally responsive dialogue.

Elixir decides what is true.

The model decides how the truth sounds.
