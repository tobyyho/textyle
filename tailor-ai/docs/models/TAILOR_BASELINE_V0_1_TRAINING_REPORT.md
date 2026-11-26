# Tailor Baseline v0.1 Training Report

## Reproducible setup

- Command: `.venv\Scripts\python.exe scripts\training\train_baseline.py --mode pilot --run-id pilot-20260806-001`
- Seed 20260806; PyTorch 2.13.0+cu130; torchvision 0.28.0+cu130; RTX 5080; AMP enabled.
- Official `EfficientNet_B0_Weights.DEFAULT` (`IMAGENET1K_V1`), seven-logit classifier replacement.
- 11,100 rows: train 7,708; validation 1,682; test 1,710. Test was not loaded by training.
- Inverse-square-root class weights, label smoothing 0.1, AdamW, gradient clipping 1.0.

## Capacity probe

Batch 16/32/64/96/128 peak reserved memory: 0.93/1.77/3.48/5.06/6.61 GB; no OOM. Batch 128 selected. Workers 2 achieved 320.72 images/s versus workers 4 at 262.22; workers 2 selected.

## Runs

Smoke `smoke-20260806-001`: two epochs, 16.81 s, best epoch 2, validation macro-F1 0.4120, checkpoint round trip passed.

Pilot `pilot-20260806-001`: three frozen-backbone warm-up plus fifteen full-finetune epochs; no early stop; 338.09 s; peak allocated/reserved 5.89/6.60 GB. Epoch 16 won by validation macro-F1 0.7676725 with validation loss 1.0133469. Parameters: total/full-trainable 4,016,515; warm-up trainable 8,967.

## Problems and reproducibility notes

The first official weight request ended with an SSL decrypt error; a bounded `curl.exe` retry from the same official PyTorch URL succeeded and hash validation passed. An initial cache-parent error caused one redundant official cache copy; code was corrected without deleting user data. A non-fatal loss conversion warning was fixed before pilot training. Deterministic algorithms are requested with `warn_only=True`; exact cross-hardware bit identity is not guaranteed.
