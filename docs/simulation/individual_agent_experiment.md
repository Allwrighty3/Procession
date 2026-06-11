# Individual Agent Simulation Experiment

## Purpose

This document turns the internal field model into a small, testable design target.

The goal is not to implement the final inner-life system. The goal is to define the smallest useful experiment that can show whether an individual NPC can preserve invisible internal continuity across interactions.

The experiment asks:

> Can one NPC maintain an internal field that changes over time and affects later speech or behavior, even when that internal change was not immediately expressed?

If the answer is yes, Procession moves beyond prompt-response dialogue and toward agency-shaped simulation.

## Why start with one individual?

The long-term vision still includes large-scale cascading world generation. This experiment does not shrink that vision.

It deliberately starts with one individual because a village adds too many moving parts too early:

- many NPCs;
- many relationships;
- rumors;
- schedules;
- factions;
- memory propagation;
- generated local scopes;
- selective live spawning;
- social consequences.

A village of shallow agents is easy. One individual with an inner field that persists and changes is harder and more useful.

The first experiment should prove the inner model at the smallest meaningful scale.

## Experiment thesis

One individual should be able to:

1. receive a presentation from an interaction;
2. update private internal field state;
3. preserve that internal change without immediately expressing all of it;
4. revisit or reactivate prior field material in a later interaction;
5. produce a later response that reflects the accumulated field state.

The important visible result is delayed continuity:

```text
Interaction 1 changes the NPC internally.
Interaction 2 shows that the NPC carried that internal change forward.
```

## Current implementation checkpoint

The first implementation now proves a generalized version of the original Tobin/Mira experiment:

- player speech is converted into a structured presentation;
- active scene entities can become presentation targets;
- presentation targets carry entity-backed public facts such as role and temperament;
- live internal field processes track topic salience, topic pressure counts, disclosure boundaries, trust deltas, private concerns, and presentation history;
- field mechanics are topic-key based rather than Mira-specific;
- dialogue constraints are derived from both the current presentation and the speaker's internal field snapshot;
- public identity, relationship denial, repeated-topic pressure, and location refusal are represented as response shapes;
- deterministic dialogue rendering consumes response shapes for any speaker;
- public identity rendering uses entity facts instead of adapter-invented facts;
- command results expose presentation and dialogue constraint metadata for debugging;
- `field for <NPC>` exposes the current internal field snapshot.

A regression test now demonstrates the generalized loop with Mira carrying internal field pressure about Tobin across multiple player questions.

Example generalized loop:

```text
> talk to Mira: Who is Tobin?
Mira says: "Tobin is a merchant. Why are you asking?"

> talk to Mira: Where is Tobin?
Mira says: "I don't share where Tobin is with strangers."

> field for Mira
Internal field for Mira:
- topic_salience: %{tobin: :high}
- topic_pressure_counts: %{tobin: 2}
- disclosure_boundaries: %{tobin: :very_high}
- trust_deltas: %{"player" => -2}
- private_concerns: [:player_asking_about_tobin, :player_repeatedly_asking_about_tobin]
- presentations: 2
```

This is still a scaffold. The implementation proves the architecture path, not the final mental model.

## Temporary scaffolding and replacement pressure

The current system intentionally contains deterministic, hardcoded scaffolding. This was useful for proving the loop, but it should not be allowed to fossilize.

Current scaffolding includes:

- phrase-based intent detection in `PresentationDetector`;
- simple topic pressure rules in `InternalField`;
- simple response-shape policy in `DialogueConstraints`;
- template rendering in `FakeAdapter`;
- generic trust deltas that always decrease when the player presses a field topic;
- generic disclosure boundaries that rise after repeated pressure;
- simple private concern atoms such as `:player_asking_about_tobin`.

These are acceptable as experiment supports because they sit behind useful boundaries:

```text
PresentationDetector
→ InternalField
→ DialogueConstraints
→ renderer/adapter
```

The current risk is not that these stand-ins exist. The risk is continuing to add new special cases instead of replacing the layer that caused the special case.

Preferred cleanup direction:

- replace phrase-specific detection with context-aware presentation extraction;
- replace fixed topic pressure rules with per-agent threshold profiles;
- replace generic disclosure boundaries with topic/relationship-specific disclosure policy;
- replace response-shape templates with validated rendering from structured constraints;
- keep Elixir responsible for authoritative field state and policy;
- keep any LLM, if used, limited to rendering or candidate proposal, not ownership of internal state.

A useful rule for the next phase:

> Add a hardcoded branch only if it proves a new architectural boundary. If the boundary already exists, improve the abstraction instead.

## Scenario origin: Tobin and Mira

The first scenario reused existing NPC interaction concerns without requiring a new world.

### Seeded individual

NPC: Tobin

Relevant identity traits:

- merchant;
- cautious but neighborly;
- values privacy;
- has some meaningful relationship or obligation involving Mira;
- does not freely disclose Mira-related information to strangers.

### Seeded relationship

Relationship target: Mira

Initial field material:

- Mira matters to Tobin;
- Mira-related questions carry sensitivity;
- Tobin has reason to avoid over-disclosure;
- Tobin may answer a narrow factual question without revealing private context.

The simulation does not need to decide yet whether this relationship is family, business, friendship, promise, fear, debt, or something else. For the experiment, the important fact is that the topic has sensitivity and disclosure limits.

### Seeded threshold profile

Initial thresholds:

- low threshold for noticing sensitive questions;
- high threshold for disclosing private topic-related information;
- medium threshold for polite deflection;
- rising boundary pressure after repeated prying;
- possible later lowering of disclosure boundary if trust increases.

### Seeded field tendencies

An individual can tend to:

- notice questions about people or topics that matter;
- preserve private concern rather than immediately speak it;
- become more guarded when a stranger asks repeated sensitive questions;
- respond differently if the questioner has earned trust.

## Included concepts

The first experiment includes only a small subset of the internal field model:

- internal field snapshot;
- presentation;
- topic-key field pressure;
- disclosure boundary;
- field modulation;
- revisitation/reactivation;
- delayed expression;
- private material that is not automatically spoken;
- response policy derived from field state.

## Excluded concepts for now

The first experiment should intentionally exclude:

- dreams;
- subconscious processing;
- revelation-like presentations;
- multi-NPC social propagation;
- large-scale village simulation;
- faction planning;
- full emotional modeling;
- long-term degradation/cultivation arcs;
- LLM-owned inner reasoning;
- complex moral evaluation of field changes.

These are important later. They are not required to prove the first useful capability.

## Minimal interaction script

The original experiment supports a small sequence like this.

### Interaction 1: stranger asks about Mira

Player:

```text
Who's Mira?
```

Expected internal presentation:

```text
presentation:
  target: npc_mira
  target_name: Mira
  topic_key: :mira
  target_public_facts: %{role: "innkeeper", temperament: "watchful"}
  source: player question
  message_intent: :ask_public_identity
```

Expected field modulation:

```text
:mira topic salience becomes high.
:mira topic pressure count becomes 1.
:mira disclosure boundary is high.
Trust delta toward player decreases slightly.
A private unresolved concern is preserved.
```

Expected speech behavior:

```text
Tobin gives a minimal public-identity answer or deflection.
He does not reveal private information.
```

Example response:

```text
Mira is an innkeeper. Why are you asking?
```

### Interaction 2: player asks a narrower relationship question

Player:

```text
Is Mira your sister?
```

Expected reactivation:

```text
Prior Mira-question field material reactivates.
Player has already asked about Mira once.
Caution is higher than in interaction 1.
```

Expected field modulation:

```text
:mira topic pressure count becomes 2.
Disclosure boundary becomes very_high.
Player trust delta decreases again.
```

Expected speech behavior:

```text
Tobin can answer the narrow false premise without over-disclosing.
```

Example response:

```text
No. Why are you asking?
```

### Interaction 3: repeated prying or location request

Player:

```text
Where can I find Mira?
```

Expected reactivation:

```text
Prior Mira questions become relevant.
Player is pattern-matched as pressing into a sensitive topic.
```

Expected field modulation:

```text
Disclosure boundary remains very_high.
Location details are forbidden.
Trust availability decreases.
Possible future memory: player repeatedly asked about Mira.
```

Expected speech behavior:

```text
Tobin refuses or deflects more firmly.
```

Example response:

```text
I don't share where Mira is with strangers.
```

### Interaction 4: later trust-building event

This can be a later optional test.

Player helps Tobin or demonstrates reliability.

Expected field modulation:

```text
Player trust availability increases.
Disclosure threshold may lower slightly, but not disappear.
Prior prying remains part of field history.
```

Expected speech behavior:

```text
Tobin may become less guarded, but he still should not dump private information.
```

Example response:

```text
You've helped me, and I won't forget that. But Mira's business is still hers to tell.
```

This checks that trust can change field behavior without erasing prior history.

## What success looks like

The experiment succeeds if the NPC:

- remembers internally that the player asked about a topic before;
- becomes more guarded after repeated sensitive questions;
- does not need to say every internal concern out loud;
- changes later dialogue based on invisible field state;
- can answer narrow factual questions without over-disclosing;
- can become less guarded after trust-building without losing all boundaries;
- preserves continuity across at least three interactions;
- supports the same mechanism for more than one speaker/topic pair.

The experiment fails if the NPC:

- treats every question as isolated;
- over-discloses private information because the player asked directly;
- forgets prior sensitive questions;
- changes tone randomly without field cause;
- immediately reveals all internal reasoning;
- relies entirely on LLM prompt wording to fake continuity;
- requires every new person/topic pair to be hardcoded through every layer.

## Observable demo target

The CLI demo should show both visible dialogue and optional debug field state.

Current demo shape:

```text
> talk to Tobin: Who is Mira?
Tobin says: "Mira is an innkeeper. Why are you asking?"

> field for Tobin
Internal field for Tobin:
- topic_salience: %{mira: :high}
- topic_pressure_counts: %{mira: 1}
- disclosure_boundaries: %{mira: :high}
- trust_deltas: %{"player" => -1}
- private_concerns: [:player_asking_about_mira]
- presentations: 1

> talk to Tobin: Is Mira your sister?
Tobin says: "No. Why are you asking?"

> field for Tobin
Internal field for Tobin:
- topic_salience: %{mira: :high}
- topic_pressure_counts: %{mira: 2}
- disclosure_boundaries: %{mira: :very_high}
- trust_deltas: %{"player" => -2}
- private_concerns: [:player_asking_about_mira, :player_repeatedly_asking_about_mira]
- presentations: 2

> talk to Tobin: Where is Mira?
Tobin says: "I don't share where Mira is with strangers."
```

The debug output is not player-facing final UX. It is a development tool to verify that visible behavior is coming from internal continuity rather than prompt luck.

## Data shape to think toward, not final struct design

This is not a required final implementation, but it hints at the kind of state that may be useful later.

```text
individual:
  id
  identity_seed
  relationships
  memories
  internal_field

internal_field:
  active_presentations
  latent_material
  thresholds
  modulations
  private_concerns
  revisitation_history

presentation:
  source
  target
  target_name
  topic_key
  target_public_facts
  message_intent
  source_confidence

threshold:
  domain
  value
  affected_by

modulation:
  target
  change
  scope
  cause
  timestamp
```

Do not treat this as final struct design. It is only a reminder of the concepts that need representation.

## LLM boundary for this experiment

The LLM should not decide a character's private inner state.

The simulation should decide:

- what topic is active;
- whether prior questions matter;
- whether disclosure is constrained;
- whether trust has shifted;
- what facts are allowed;
- what facts are forbidden;
- what intent the response should serve;
- what response shape should be rendered.

The LLM, if used at all, should only render a line from structured constraints.

Good input to an LLM:

```text
Speaker: Tobin
Listener: Player
Intent: guarded deflection
Response shape: public_identity_then_question
Allowed facts: Mira is an innkeeper; Mira is not Tobin's sister
Forbidden facts: Mira's location; private history; hidden relationship details
Tone: cautious, neighborly, slightly guarded
Prior field: player has asked about Mira twice
```

Bad input to an LLM:

```text
You are Tobin. The player asks where Mira is. Answer in character.
```

That bad version invites the model to invent the mind on demand. That is exactly the surface-level behavior this experiment is meant to escape.

## Experiment boundary

This experiment should not answer every question raised in the internal field model.

It only needs to prove one thing:

> A single individual can carry private internal field changes across interactions, and those changes can alter later expression without being fully spoken.

If this works, later experiments can add:

- revisitation over time;
- dreams or latent material;
- changing abstraction radius;
- trust repair;
- competing relationships;
- multi-NPC field effects;
- world-scope consequences;
- personality-specific thresholds;
- relationship-specific disclosure policies.

## Recommended next implementation milestone

The next implementation milestone should reduce scaffolding rather than add more special cases.

Recommended next step:

```text
Introduce data-driven sensitivity/disclosure policy for topics or relationships.
```

That would let the system decide why a topic is sensitive from entity state, relationship data, or generated metadata instead of assuming every topic press creates the same boundary pattern.

Do not start a new training run for this. Do not add a village-scale system. Do not add more hand-authored relationship branches unless they prove a new boundary.
