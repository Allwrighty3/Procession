# Internal Field Simulation Model

## Purpose

Procession should not treat NPC dialogue as the primary evidence of inner life. Dialogue is only one possible expression of an ongoing internal field.

This document captures a working theory for representing inner life in Procession at a conceptual level. It is not an implementation plan yet. It exists to preserve the model before we accidentally freeze a shallow abstraction into code and then pretend the code is profound because it compiles.

The core thesis:

> Procession models inner life as an ongoing internal field rather than as discrete thoughts or prompt-response behavior. The field contains presentations, memories, tensions, desires, impressions, abstractions, and unresolved material. Speech and action emerge when field material crosses character-shaped thresholds, while revisitation, dreams, subconscious processing, and experience modulate the field over time.

## Non-goals

Procession does not attempt to:

- simulate God;
- simulate actual eternal intelligence;
- mechanically model revelation;
- define thought as a complete metaphysical mechanism;
- treat all thoughts as chosen actions;
- reduce inner life to language generation;
- label all field changes as good or bad at the simulation layer;
- spawn every latent internal process as a live runtime process;
- make the final world model flat, fully spawned, or single-pass.

The goal is narrower: represent the effects of inner phenomena well enough that individual agents can display continuity, privacy, tension, delayed expression, changed thresholds, and believable agency-shaped behavior.

## LDS ontological guardrails

This model is informed by an LDS worldview, but it should remain humble about what it claims to simulate.

Relevant guardrails include:

- Intelligence is eternal and is associated with acting rather than merely being acted upon.
- Matter is not treated as immaterial ghost-stuff; spirit is matter, though finer or purer than mortal perception normally detects.
- Humans are agents who act for themselves, but not every mental presentation is necessarily a chosen action.
- Some thoughts, impressions, dreams, or internal presentations may be uninvited.
- Sacred or spiritual experiences may require stewardship, discernment, privacy, revisitation, and later integration.
- The simulation should represent the agent's experience, interpretation, stewardship, and consequences without claiming ultimate certainty about sacred source.

Useful reference passages and concepts:

- 2 Nephi 2: agency, opposition, acting for oneself rather than merely being acted upon.
- Doctrine and Covenants 93: intelligence, light, truth, and agency.
- Doctrine and Covenants 131: spirit as matter and the rejection of immaterial matter.
- Doctrine and Covenants 9: studying something out and receiving confirmation in mind and heart.
- Luke 2: Mary keeping and pondering sacred things in her heart.
- 1 Nephi 11 and 3 Nephi 17: pondering as a preparatory and receptive activity.
- Elder Jeffrey R. Holland's comparison of some unwelcome thoughts to thieves that should not be entertained.

These references are conceptual anchors, not complete theological definitions.

## Core concept: the internal field

An individual has an ongoing internal field.

The field is not a single thought, emotion, belief, or goal. It is the active and latent internal landscape of the individual.

The field may contain:

- conscious presentations;
- subconscious or latent material;
- memories;
- dreams;
- desires;
- questions;
- abstractions;
- impressions;
- temptations;
- imagined possibilities;
- relational pressures;
- embodied pressures;
- unresolved tensions;
- sacred or private material;
- possible speech and action pathways.

The field is not emptied before action. A person usually does not wait until thinking is complete before speaking or acting. Speech and action occur when some part of the field becomes sufficiently ready, salient, pressured, appropriate, or unavoidable.

A better shape is:

```text
ongoing field
+ event or presentation
+ character-shaped thresholds
+ current embodied/social/spiritual context
-> possible expression, action, withholding, revisitation, or reorganization
-> field continues
```

Not:

```text
input -> complete thought -> output
```

That second model is too clean. Human inner life is rude enough to keep running after the line of dialogue has already left the mouth.

## Presentations

A presentation is something that appears or becomes active within the field.

A presentation may be:

- a phrase;
- an image;
- a memory;
- a fear;
- a desire;
- a question;
- a dream fragment;
- a moral discomfort;
- an imagined future;
- an intrusive idea;
- an interpreted prompting;
- an abstraction such as justice, loyalty, duty, or betrayal.

A presentation is not automatically a choice. It may be received, remembered, generated, imagined, suggested, triggered by the body, triggered by the world, or uncertain in source.

The simulation layer should preserve the distinction between:

```text
presentation appears
agent notices it
agent attends to it
agent revisits it
agent entertains it
agent acts on it
```

Those are not the same thing.

## Thresholds

Thresholds determine when field material becomes noticed, expressed, acted upon, withheld, revisited, integrated, or reorganized.

Thresholds are not a single global mental meter. They are domain-specific and character-shaped.

Examples:

- expression threshold: how much readiness is needed before the agent speaks;
- action threshold: how much readiness is needed before the agent acts;
- reflection threshold: how much tension or salience is needed before the agent looks back;
- disclosure threshold: how much trust or pressure is needed before the agent shares private material;
- revision threshold: how much evidence is needed before the agent changes an interpretation;
- insight threshold: how much coherence or readiness is needed before an epiphany-like reorganization occurs;
- stewardship threshold: how readily the agent holds, protects, tests, or refuses internal material.

Thresholds differ by person, domain, relationship, history, fatigue, trust, fear, maturity, humility, spiritual sensitivity, and current context.

A character like Luffy is not necessarily thoughtless. A better description is that some pathways from salience to action have unusually low thresholds, especially around friends, oppression, hunger, and freedom. In other domains, such as abstract planning, the thresholds may be much higher. As a character develops, thresholds can shift without replacing identity.

## Revisitation

Revisitation is the generalized "looking back" operation.

It is the return of attention to prior field material. This can reactivate and alter that material.

At the simulation layer, revisitation should not begin as separate hard-coded primitives such as reflection, rumination, pondering, repentance, resentment, gratitude, analysis, or rehearsal. Those can be understood as downstream patterns or interpretations of a more general operation.

Conceptually:

```text
revisit(target, field, context)
-> reactivates prior material
-> alters salience, scope, tension, thresholds, availability, or integration
-> field continues
```

Possible revisitation patterns:

- reflection-like: permits reinterpretation, comparison, and integration;
- rumination-like: repeatedly reactivates material while preserving or intensifying a current interpretation;
- pondering-like: holds material with patience, sacredness, or openness;
- rehearsal-like: strengthens a possible speech or action pathway;
- resentment-like: repeatedly reactivates injury with blame salience;
- gratitude-like: repeatedly reactivates help, mercy, or blessing with positive salience;
- repentance-like: revisits action, consequence, accountability, and change;
- discernment-like: revisits source, meaning, and fit with truth.

The base operation is revisitation. The labels are later descriptions of field behavior.

## Field modulation

Field modulation is any change in how the field behaves.

The simulation layer should avoid immediately labeling modulations as good or bad. It should describe what changed.

Examples:

- salience increased;
- salience decreased;
- trust availability changed;
- disclosure threshold rose;
- threat detection threshold lowered;
- memory became more active;
- a possible action became more available;
- a relationship pressure became stronger;
- integration capacity shifted;
- a private tension remained unresolved;
- a presentation faded;
- a dream made latent material conscious;
- an insight reorganized several unresolved pieces.

Later narrative, doctrine, consequence, or agent values may interpret a modulation as growth, degradation, protection, hardening, healing, temptation, wisdom, avoidance, or repentance. The simulation itself should first preserve the field change without preaching at the player.

## Degradation and cultivation

Degradation and cultivation are interpretive names for field modulations that alter capacities over time.

At the neutral simulation layer, prefer descriptions such as:

- reduced availability;
- increased availability;
- dulled sensitivity;
- heightened sensitivity;
- narrowed scope;
- widened scope;
- reduced flexibility;
- increased flexibility;
- reduced receptivity;
- increased receptivity;
- stronger resistance;
- weaker resistance;
- stronger integration;
- weaker integration.

Potential domains include:

- perception;
- salience;
- memory access;
- interpretation;
- desire;
- moral sensitivity;
- trust;
- integration;
- expression;
- effective agency;
- spiritual receptivity as interpreted by the agent or world model.

A field modulation may protect the agent in one context and limit the agent in another. The simulation should track the effect and let consequence, story, and agency reveal its meaning.

## Scope and abstraction radius

Events may alter the field at different scopes.

A betrayal, for example, might update only:

```text
this event
this person
this relationship
this type of person
this institution
people generally
myself
God/reality
```

This should be represented as scope or abstraction radius, not prematurely judged as correct or incorrect.

The same event can remain local, become categorical, become global, or attach to self-understanding. Different individuals may have wildly different thresholds for when a specific experience changes broader thresholds.

This creates meta-thresholds:

- how easily does one experience change future trust?
- how many similar experiences widen the scope?
- how much contrary evidence narrows the scope again?
- how much pain, fear, humility, pride, fatigue, or love affects the update?

Scope changes are central to character continuity.

## Dreams, subconscious material, and source ambiguity

Subconscious thought and dreams should be represented by abstraction, not by pretending to explain their actual mechanisms.

The key rule:

> Do not simulate what the subconscious is. Represent what it does to the field.

Subconscious or latent material may:

- preserve unresolved tension;
- form associations;
- alter mood;
- alter future thresholds;
- surface later as a phrase, image, memory, unease, dream, hesitation, or epiphany;
- combine unrelated material symbolically;
- intensify or soften salience;
- delay expression;
- make later conscious insight more likely.

Dreams may function as sleep-state presentations of field material. They may be fragmentary, symbolic, emotional, narrative, confusing, meaningful, meaningless, or interpreted as spiritually significant by the agent.

A dream should not automatically be treated as revelation, prophecy, or random noise. Its source and meaning may remain uncertain.

Useful distinction:

```text
actual source: what the simulation/world may know, if anything
perceived source: what the agent believes or wonders about
source confidence: how strongly the agent holds that interpretation
integration state: whether the dream has been ignored, revisited, tested, feared, treasured, or integrated
```

For sacred or poorly understood phenomena, represent the experience, interpretation, stewardship, and consequences rather than claiming ultimate metaphysical source.

## Reorganization and epiphany

An epiphany is a reorganization of the field into sudden coherence.

It can happen when:

- existing unresolved pieces finally fit;
- a new presentation reframes old material;
- repeated revisitation changes readiness;
- a dream or memory surfaces missing material;
- outside instruction or experience supplies a key relation;
- the agent interprets something as spiritual illumination;
- tension crosses an insight threshold.

An epiphany may be both received and integrated. Even a profound revelation-like experience may still require internal work to fit the pieces together.

At the simulation layer, represent epiphany as field reorganization:

```text
before:
  several memories, tensions, questions, and desires are active but unresolved

after:
  a new relation or interpretation makes them cohere
  thresholds and future interpretations may change
  the field continues
```

Do not treat epiphany as a final answer machine. The agent may still need to revisit, steward, test, express, or live into the new coherence.

## Stewardship over internal material

Stewardship is the responsibility to care for what has entered the field.

This includes deciding, consciously or characteristically, whether to:

- hold it;
- speak it;
- test it;
- pray over it;
- revisit it;
- refuse it;
- let it pass;
- protect it;
- keep it sacred;
- act on it;
- wait.

This model preserves the difference between an unwanted presentation and the choice to entertain it. It also preserves the difference between material that should be rejected and material that should be held carefully.

In Procession, some internal material should be private. Not everything meaningful should become dialogue.

## Simulation implications

The internal field model suggests that an individual agent should eventually support:

- seeded identity;
- seeded values;
- seeded memories;
- seeded relationships;
- domain-specific thresholds;
- field modulations over time;
- latent material;
- open loops;
- revisitation tendencies;
- scope/abstraction radius tendencies;
- expression tendencies;
- private material;
- delayed consequences;
- reorganization events.

The first practical experiments should likely focus on one individual rather than a village. A village adds social complexity before the inner model is understood.

A useful early experiment could involve:

```text
one seeded individual
one meaningful relationship
one wound or unresolved tension
one repeated revisitation pattern
one dream or latent presentation
one changed threshold
one delayed expression
```

This is not the final architecture. It is a test of whether the model can produce more believable continuity than prompt-response dialogue.

## What Elixir, companion systems, and LLMs should own

Elixir should remain authoritative over the simulation kernel:

- world state;
- entity state;
- event logs;
- memory records;
- thresholds;
- field modulations;
- validation;
- speech/action constraints;
- player-facing API;
- scope activation;
- selective live spawning.

The LLM should not own the mind. It should help render or propose expression from structured state.

Good LLM role:

```text
structured field snapshot
+ speaker identity
+ listener
+ intent/disclosure constraints
+ allowed facts
+ forbidden facts
+ tone
-> candidate natural-language expression
```

Bad LLM role:

```text
raw prompt
-> entire inner life and final answer invented on demand
```

Python may be useful later for training, embeddings, diagnostics, semantic memory experiments, and analysis. Rust may be useful later for narrow performance-heavy systems such as graph traversal, activation spreading, spatial indexing, or similarity search. Neither should replace Elixir as the authoritative simulation core unless the project direction fundamentally changes.

## Working vocabulary

- **Internal field**: the ongoing active and latent inner landscape of an individual.
- **Presentation**: something that appears or becomes active in the field.
- **Threshold**: a character-shaped condition under which field material becomes noticed, expressed, acted upon, withheld, revisited, integrated, or reorganized.
- **Revisitation**: the generalized looking-back operation that reactivates prior field material.
- **Field modulation**: any change in salience, threshold, availability, sensitivity, scope, tension, or integration.
- **Scope / abstraction radius**: how widely an event updates future interpretation.
- **Stewardship**: the care, testing, holding, rejection, expression, or protection of internal material.
- **Latent material**: field material that is present below direct awareness or expression.
- **Reorganization**: a major shift in field coherence, including epiphany-like events.
- **Expression**: speech, action, silence, hesitation, or other outward manifestation of field state.

## Current thesis

Procession should not try to simulate thought as a single object or mechanism. Thought is better treated as a broad phenomenological domain, somewhat like chemistry is a domain of interactions rather than a single substance.

For practical purposes, Procession should represent an individual's ongoing internal field and the ways that presentations, thresholds, revisitation, modulation, scope, dreams, latent material, stewardship, and reorganization shape future expression and action.

This gives the project a path beyond dialogue imitation while remaining honest about what is and is not being simulated.
