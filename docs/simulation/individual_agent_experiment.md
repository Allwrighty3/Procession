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

## Scenario candidate: Tobin and Mira

This experiment can reuse existing NPC interaction concerns without requiring a new world.

### Seeded individual

NPC: Tobin

Relevant identity traits:

- trader;
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

- low threshold for noticing Mira-related questions;
- high threshold for disclosing private Mira-related information;
- medium threshold for polite deflection;
- rising threshold for trust after repeated prying;
- possible later lowering of disclosure threshold if trust increases.

### Seeded field tendencies

Tobin tends to:

- notice questions about people he values;
- preserve private concern rather than immediately speak it;
- become more guarded when a stranger asks repeated sensitive questions;
- respond differently if the questioner has earned trust.

## Included concepts

The first experiment includes only a small subset of the internal field model:

- internal field snapshot;
- presentation;
- threshold;
- field modulation;
- revisitation/reactivation;
- delayed expression;
- scope/abstraction radius at a simple level;
- private material that is not automatically spoken.

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

The experiment should support a small sequence like this.

### Interaction 1: stranger asks about Mira

Player:

```text
Who's Mira?
```

Expected internal presentation:

```text
presentation:
  target: Mira
  source: player question
  salience: high
  reason: sensitive relationship/topic
```

Expected field modulation:

```text
Mira-topic salience increases.
Disclosure threshold remains high.
Suspicion or caution toward player increases slightly.
A private unresolved concern is preserved.
```

Expected speech behavior:

```text
Tobin gives a minimal answer or deflection.
He does not reveal private information.
```

Example response:

```text
A merchant. Why are you asking?
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
Mira-topic sensitivity rises again.
Player trust availability decreases slightly.
Disclosure threshold remains high.
```

Expected speech behavior:

```text
Tobin can answer the narrow false premise without over-disclosing.
```

Example response:

```text
No. Why are you asking?
```

### Interaction 3: repeated prying

Player:

```text
Where can I find her?
```

Expected reactivation:

```text
The two prior Mira questions become relevant.
Player is now pattern-matched as prying into a sensitive topic.
```

Expected field modulation:

```text
Disclosure threshold increases further.
Deflection threshold lowers.
Trust availability decreases.
Possible future memory: player repeatedly asked about Mira.
```

Expected speech behavior:

```text
Tobin refuses or deflects more firmly.
```

Example response:

```text
That's not something I share with strangers.
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

- remembers internally that the player asked about Mira before;
- becomes more guarded after repeated sensitive questions;
- does not need to say every internal concern out loud;
- changes later dialogue based on invisible field state;
- can answer narrow factual questions without over-disclosing;
- can become less guarded after trust-building without losing all boundaries;
- preserves continuity across at least three interactions.

The experiment fails if the NPC:

- treats every question as isolated;
- over-discloses private information because the player asked directly;
- forgets prior sensitive questions;
- changes tone randomly without field cause;
- immediately reveals all internal reasoning;
- relies entirely on LLM prompt wording to fake continuity.

## Observable demo target

A future IEx or CLI demo should show both visible dialogue and optional debug field state.

Possible demo shape:

```text
> talk to tobin: who's mira?
Tobin says: "A merchant. Why are you asking?"

> debug field tobin
active:
  mira_topic_salience: high
  player_trust_delta: -1
  disclosure_boundary[:mira]: high
  private_concerns: [:player_prying_about_mira]

> talk to tobin: is mira your sister?
Tobin says: "No. Why are you asking?"

> debug field tobin
active:
  mira_topic_salience: very_high
  player_trust_delta: -2
  disclosure_boundary[:mira]: very_high
  private_concerns: [:player_repeatedly_prying_about_mira]

> talk to tobin: where can I find her?
Tobin says: "That's not something I share with strangers."
```

The debug output is not player-facing final UX. It is a development tool to verify that visible behavior is coming from internal continuity rather than prompt luck.

## Data shape to think toward, not implement yet

This is not a required implementation, but it hints at the kind of state that may be useful later.

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
  salience
  reason
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

The LLM should not decide Tobin's private inner state.

The simulation should decide:

- Mira is sensitive;
- prior questions matter;
- disclosure is constrained;
- trust has shifted;
- what facts are allowed;
- what facts are forbidden;
- what intent the response should serve.

The LLM, if used at all, should only render a line from structured constraints.

Good input to an LLM:

```text
Speaker: Tobin
Listener: Player
Intent: guarded deflection
Allowed facts: Mira is a merchant; Mira is not Tobin's sister
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
- world-scope consequences.

## Recommended next implementation milestone

After this document, the next implementation milestone should be tiny:

```text
Create a minimal internal field state for one NPC and update it across repeated talk interactions.
```

No training run. No new model. No village. No grand theory engine.

Just one NPC whose later response proves something invisible changed earlier.
