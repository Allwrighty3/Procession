# Procession

An experimental living world engine where every NPC, faction, and location is an independent OTP process. Features emergent storytelling through message passing, hierarchical memory systems, and a procedural game generator powered by local LLMs (Ollama). Built with Phoenix LiveView.

## Current Status

Procession currently has a tested Phase 1/Phase 2 foundation:

- OTP application supervision with a registry and dynamic entity supervisor
- Entity processes backed by GenServer
- Entity-to-entity message passing
- Structured memory entries created from messages
- Hierarchical memory promotion:
  - short memory: 10 entries
  - medium memory: 50 entries
  - long memory: 200 entries
- Keyword-based memory recall
- Full memory recall in priority order

