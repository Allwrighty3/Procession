# Local ROCm Training Setup

This document records the working local AMD GPU training setup for Procession model-training experiments.

## Hardware

- GPU: AMD Radeon RX 6700 XT
- ROCm device name: `gfx1031`
- ROCm compatibility override required:
  - `HSA_OVERRIDE_GFX_VERSION=10.3.0`
  - `HCC_AMDGPU_TARGET=gfx1031`

## Working environment

The working training environment lives outside the Procession repo:

```bash
~/procession-ai-training
```

The working Python virtual environment is:

```bash
~/procession-ai-training/.venv-rocm64
```

Activate it with:

```bash
source ~/procession-ai-training/activate_rocm64_training.sh
```

Expected versions:

```text
torch: 2.9.1+rocm6.4
hip: 6.4.43484-123eb5128
device: AMD Radeon RX 6700 XT
```

## Important failed environment

The AMD ROCm 7.1 PyTorch wheel environment failed for training:

```text
torch: 2.8.0+rocm7.1.0
hip: 7.1.x
```

Observed behavior:

- PyTorch imports successfully.
- ROCm sees the GPU.
- Forward tensor math works.
- Transformers inference can start.
- Backward pass segfaults.

Do not use that environment for training.

## Verified working tests

The ROCm 6.4 environment successfully passed:

```bash
python scripts/backprop_smoke_test.py
python scripts/lora_smoke_train.py
python scripts/lora_smoke_generate.py
```

Confirmed capabilities:

- GPU tensor backward pass works.
- Tiny neural network training works.
- SFT JSONL loads.
- LoRA adapter training runs on the RX 6700 XT.
- Adapter saves to disk.
- Adapter reloads for inference.

## Current smoke-test artifact

The smoke-test adapter is local-only:

```bash
~/procession-ai-training/outputs/npc_lora_smoke
```

This is not a useful gameplay model. It only proves the local training pipeline works.

## Procession training data

Canonical training export:

```bash
priv/training/exports/npc_interaction_training_export.jsonl
```

Generated SFT view:

```bash
priv/training/exports/npc_interaction_sft.jsonl
```

Converter:

```bash
scripts/build_npc_training_text.py
```

Training data remains non-authoritative. It is used to shape models, not to define simulation truth.
