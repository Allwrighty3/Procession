# AMD ROCm Training Feasibility

## Purpose

This document tracks whether the available AMD desktop can realistically be used for local NPC interaction LoRA or QLoRA experiments.

## Known hardware

```text
GPU: AMD Radeon RX 6700 XT
Dedicated GPU memory: 12.0 GB
Shared GPU memory: 16.0 GB
System RAM: ~32 GB
OS: Windows 11 Home
Driver version: 32.0.21043.10005
Driver date: 2026-05-12
WSL installed: no
```

## Current status

The desktop has enough VRAM for small-model adapter experiments.

The unresolved question is software support:

> Can the RX 6700 XT run a practical local AMD ROCm-based fine-tuning stack for a small Llama-family model?

## Feasibility questions

Before selecting tooling, answer:

- Is RX 6700 XT supported well enough by ROCm for PyTorch training?
- Is Linux required, or can the stack work acceptably from Windows?
- Is WSL2 viable for AMD ROCm in this case?
- Would native Linux dual boot or a separate Linux install be simpler?
- Does Unsloth support the required AMD path?
- Does Axolotl support the required AMD path?
- Can the output adapter be converted or loaded for local inference?
- Is setup effort worth it compared with temporary external NVIDIA compute?

## Recommended decision rule

Use the desktop for training only if:

- ROCm support for RX 6700 XT is confirmed
- PyTorch can see and use the GPU
- a small LoRA/QLoRA training script can run without CPU fallback
- setup does not add training dependencies to normal Elixir development
- the output adapter can be evaluated against the existing NPC interaction evals

If any of those fail, defer training or use temporary external compute.

## Minimum proof command

The minimum useful proof is not a full training run.

The first proof should be:

1. Install or access the candidate training environment.
2. Confirm PyTorch sees the AMD GPU.
3. Run a tiny GPU tensor operation.
4. Load a small model or tiny test model.
5. Run a tiny LoRA smoke test if tooling supports it.

## Success criteria

This feasibility step is complete when the project has a clear answer:

```text
Local AMD training path: viable / not viable / deferred
Recommended tooling: Unsloth / Axolotl / other / external compute / deferred
Reason:
```

## Current recommendation

Do not install a full training stack yet.

First research ROCm support for RX 6700 XT and the current state of Unsloth or Axolotl on AMD hardware.

Keep the Elixir export/eval path moving while this hardware/tooling question is resolved.
