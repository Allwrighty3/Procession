# Procession Architecture

## Core Modules

### Procession.Entity
Path: `lib/procession/entity.ex`

Responsible for:
- Entity process state
- Message receiving
- Memory updates
- Recall APIs

Important functions:
- `start_link/1`
- `send_message/2`
- `send_to/3`
- `get_state/1`
- `describe/1`
- `recall/2`
- `recall_all/1`

### Procession.EntitySupervisor
Path: `lib/procession/entity_supervisor.ex`

Responsible for:
- Starting entity processes
- Stopping entity processes
- Registry lookup
- Listing active entities

Important functions:
- `start_entity/2`
- `stop_entity/1`
- `exists?/1`
- `lookup_entity/1`
- `list_entities/0`

### Procession.Memory
Path: `lib/procession/memory.ex`

Responsible for:
- Creating memory entries
- Short / medium / long memory promotion
- Memory search
- Memory ordering