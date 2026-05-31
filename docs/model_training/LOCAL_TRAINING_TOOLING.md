# Local Training Tooling

## Decision

The current laptop/development machine is not a practical local fine-tuning target because available VRAM is approximately:

```text
0.5 GB
```

A separate desktop is available with:

```text
GPU: AMD Radeon RX 6700 XT
Dedicated GPU memory: 12.0 GB
Shared GPU memory: 16.0 GB
System RAM: ~32 GB
OS: Windows 11 Home
Driver version: 32.0.21043.10005
Driver date: 2026-05-12
WSL: not currently installed
```

The desktop has enough VRAM for small-model LoRA or QLoRA experiments. The remaining constraint is software support because the GPU is AMD rather than NVIDIA/CUDA.

## Current recommendation

Do not train on the laptop.

Use the desktop as the likely local training machine.

The chosen first training path is:

```text
Unsloth AMD on Linux/ROCm
```

Backup path:

```text
Axolotl ROCm
```

The RX 6700 XT has enough VRAM for small-model LoRA or QLoRA experiments. The remaining practical risk is ROCm/software setup, not hardware capacity.

Recommended next path:

1. Keep validation/export/eval tooling in Elixir.
2. Keep Ollama as the local inference baseline.
3. Use the RX 6700 XT desktop for the first local training attempt if Linux/ROCm setup is acceptable.
4. Try Unsloth AMD first.
5. Use Axolotl ROCm as the backup if Unsloth fails or if explicit YAML configuration becomes more useful.
6. Avoid training from scratch.
7. Avoid adding Python training dependencies to the default project path.

## Hardware notes

Task Manager confirms the desktop has:

```text
Dedicated GPU memory: 12.0 GB
Shared GPU memory: 16.0 GB
```

For training decisions, dedicated GPU memory is the important number. Shared GPU memory is borrowed system memory and should not be treated as equivalent to VRAM.

The RX 6700 XT clears the likely VRAM threshold for small-model adapter experiments. The main risk is AMD tooling support.

## Tooling implication

Because the desktop uses an AMD GPU, the first training attempt should not assume the standard NVIDIA/CUDA path.

Chosen path:

- primary: Unsloth AMD on Linux/ROCm
- backup: Axolotl ROCm
- serving/eval: Ollama and existing Elixir eval tooling

Windows-native training is not the first attempt.

WSL is not assumed.

The first proof should be a small ROCm/PyTorch GPU smoke test before installing or configuring the full training stack.

## First experiment target

The first model target can still be:

```text
llama3.2:1b
```

But for training, the important question is not only model size. It is whether the available AMD stack can train the chosen base model with LoRA or QLoRA reliably.

## Non-goals

Do not:

* train a model from scratch
* force CPU-only fine-tuning into the main project path
* add Python training dependencies to the default Elixir test path
* require Ollama for normal `mix test`
* require training tooling for normal gameplay development
* treat training output as authoritative simulation state
* import generated model output into entity memory
* create behavior metadata from training artifacts

## Training data source

The current export command is:

```bash
mix procession.training.npc_interaction.export
```

Default export path:

```text
priv/training/exports/npc_interaction_training_export.jsonl
```

The exported file is sorted by `id` for reproducibility and marks examples as non-authoritative metadata.

## Local readiness checklist

Before any future training attempt:

```bash
mix procession.training.npc_interaction.validate
mix procession.training.npc_interaction.export
mix test
```

## Desktop hardware discovery

The available desktop may be useful for training experiments, but the software path still needs to be confirmed.

Do not assume WSL is installed.

Start with native Windows hardware discovery.

### Windows PowerShell

Run these commands in PowerShell:

```powershell
Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM
Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version
Get-PSDrive C
```

If AMD tooling is installed, also confirm the GPU and VRAM through AMD Adrenalin, Task Manager, GPU-Z, or another GPU utility.

Useful minimum information to record:

```text
GPU: AMD Radeon RX 6700 XT
Dedicated GPU memory: 12.0 GB
Shared GPU memory: 16.0 GB
System RAM: ~32 GB
OS: Windows 11 Home
Driver version: 32.0.21043.10005
Driver date: 2026-05-12
CUDA available: no
ROCm available: not confirmed
WSL installed: no
Docker available: unknown
```

### Optional Linux/WSL checks

Only run these if Linux or WSL is already available:

```bash
nvidia-smi
lspci | grep -Ei 'vga|3d|display'
free -h
df -h
uname -a
python3 --version
```

For AMD GPU training, Linux/ROCm compatibility is more relevant than CUDA checks.

## Hardware-based decision

Use this rough decision rule:

* **0.5 GB VRAM**: no local fine-tuning
* **4 GB VRAM**: maybe tiny/experimental QLoRA only, expect pain
* **6–8 GB VRAM**: reasonable first small-model LoRA/QLoRA experiments if tooling supports the GPU
* **12+ GB VRAM**: much better local experimentation target if tooling supports the GPU

The RX 6700 XT clears the VRAM threshold. The AMD software stack is now the main question.

## Practical next step

The next practical step is a ROCm/PyTorch smoke test on the desktop, not a full training run.

The smoke test should prove:

- the AMD GPU is visible to the training environment
- PyTorch can use the GPU through ROCm
- a tiny GPU tensor operation succeeds
- the project can keep Python training tooling outside the Elixir runtime path

Only after that should Procession attempt a tiny Unsloth LoRA experiment.

## Success criteria for future training

A future training experiment should answer one question:

> Can a small LoRA improve NPC interaction grounding without making runtime architecture worse?

Success means:

* fewer identity drift failures
* fewer invented locations
* fewer invented current activities
* better uncertainty behavior
* no training dependency added to normal Elixir tests
* no generated output imported as world truth

Failure is acceptable if it teaches us whether training is worth continuing.

