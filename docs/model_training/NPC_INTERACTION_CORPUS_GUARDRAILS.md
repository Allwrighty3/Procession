# NPC Interaction Corpus Guardrails

## Purpose

The NPC interaction training corpus teaches bounded response behavior.

It is not world state.
It is not entity memory.
It is not behavior metadata.
It is not simulation history.
It is not authoritative lore.

The corpus exists to help models learn how to answer from grounded context without inventing unsupported facts.

## Non-authoritative status

Training examples are inert data.

They may contain example names, locations, relationships, memories, and responses, but those details are only teaching fixtures unless they also exist in authoritative simulation state or intentionally authored fixture data.

A training example mentioning an NPC, location, event, or memory does not create that thing in the game world.

## Forbidden uses

The corpus must not be used to:

- import generated model outputs into entity memory
- create or update entity state
- create behavior metadata
- create world state
- create active scopes
- create canonical lore
- mark relationships as real
- mark locations as real
- mark memories as real
- bypass validation boundaries

## Allowed uses

The corpus may be used to:

- train or fine-tune bounded NPC interaction behavior
- evaluate whether responses preserve identity
- evaluate whether responses avoid unsupported invention
- evaluate whether responses answer the immediate speaker message
- provide contrastive examples of accepted and rejected responses
- test prompt or scoring changes outside runtime simulation

## Runtime separation

Runtime simulation must continue to derive truth from Elixir-owned state:

- entity state
- entity memory
- behavior metadata
- active scopes
- world state
- validated generated content
- authored fixtures

Training examples may resemble runtime data, but resemblance is not authority.

## AI-generated additions

AI-generated training examples are untrusted until reviewed or validated.

Before adding generated examples to the corpus, confirm that:

- the context is internally consistent
- the expected response is grounded only in the provided context
- rejected responses demonstrate useful failure modes
- examples do not imply new authoritative lore
- examples do not contain executable behavior
- examples do not mutate simulation state

## Rule of thumb

If a fact appears only in the training corpus, it teaches response behavior.

It does not become true in the world.