# Training Runtime Boundaries

## Purpose

Training tooling must stay outside Procession's normal runtime and default development path.

Procession is Elixir/OTP-first. Training tools may help improve model behavior, but they must not become required for normal simulation, gameplay, testing, or development.

## Runtime boundary

Normal Procession runtime must not require:

- Python training packages
- Unsloth
- Axolotl
- ROCm
- CUDA
- Docker
- WSL
- Hugging Face tooling
- local model artifacts
- generated adapter files

Default Elixir tests must continue to run without training tools installed.

## Allowed project-owned pieces

The repo may contain:

- curated training examples
- validation loaders
- export Mix tasks
- eval runners
- documentation
- small deterministic fixtures
- scripts that are explicitly optional

These pieces are allowed because they support training readiness without making training part of runtime behavior.

## Disallowed runtime assumptions

Do not:

- add training dependencies to `mix.exs`
- require training tools for normal `mix test`
- require Ollama for normal `mix test`
- import generated model outputs into entity memory
- create behavior metadata from generated outputs
- treat training examples as world truth
- load local adapter artifacts automatically during normal startup
- make gameplay depend on a locally trained adapter

## Model artifact location

Generated model artifacts should live outside normal runtime code.

Preferred local paths:

```text
priv/training/exports/
priv/training/artifacts/
```

Large generated artifacts should not be committed unless intentionally documented.

Examples of artifacts that should usually remain local:

```text
*.safetensors
*.gguf
adapter_config.json
adapter_model.safetensors
checkpoint-*/
runs/
wandb/
```

## Git hygiene

Training output can become large quickly.

Before committing training-related files, check:

```bash
git status
git diff --stat
```

Do not commit large model outputs accidentally.

If model artifacts need to be tracked later, document why and consider Git LFS or an external artifact store.

## Runtime use of trained adapters

A trained adapter may only become part of runtime after:

1. it has been evaluated against NPC interaction evals,
2. it improves useful failure categories,
3. it does not introduce worse identity drift or invention,
4. its base model compatibility is documented,
5. its artifact location is documented,
6. loading it is optional or intentionally configured.

## Rule of thumb

Training can improve the model.

Training must not become the simulation.