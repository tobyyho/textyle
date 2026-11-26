# Tailor AI Provisional Training Profiles

These profiles are planning constraints only. No dataset, architecture, training duration, or exact batch size is approved by this document, and no training occurred in Milestone 1.

The ranges reflect the verified RTX 5080 with approximately 16 GiB VRAM, 32 GB-class system RAM, NVMe storage, and a one-student AI workload. Exact batch sizes must be determined experimentally after the model, image pipeline, and dataset exist. Dataset images should normally stream from NVMe storage; full-dataset caching in RAM is prohibited. Mixed precision is expected where numerically safe.

## Smoke profile

**Purpose:** Verify future data and training pipelines on a tiny, explicitly approved subset. It should finish quickly, use very few epochs, and produce no performance claims.

| Setting | Provisional range or policy |
|---|---|
| Image resolution | 160-224 px square |
| Batch size | 4-16, determined experimentally |
| Epochs | 1-2 |
| DataLoader workers | 0-2 on Windows |
| Mixed precision | Expected; compare once against full precision for correctness |
| Checkpoint frequency | End only, or none if the pipeline is disposable |
| Intended duration category | Minutes, not a formal duration promise |
| Free-space guard | Stop before available experiment storage falls below 100 GiB |
| Approval requirement | Explicit instruction to run the smoke training milestone |

## Daytime profile

**Purpose:** Run a moderate experiment during normal working hours, allow iterative debugging, and remain conservative with memory and heat.

| Setting | Provisional range or policy |
|---|---|
| Image resolution | 192-320 px square |
| Batch size | 8-48, determined experimentally with headroom |
| Epochs | 3-15 |
| DataLoader workers | 2-6; monitor system RAM and Windows worker stability |
| Mixed precision | Expected |
| Checkpoint frequency | Every 1-3 epochs plus best validation state |
| Intended duration category | Interactive daytime experiment; no precise duration assigned |
| Free-space guard | At least 100 GiB free, plus estimated checkpoint/cache growth |
| Approval requirement | User-approved experiment scope and dataset subset |

## Overnight profile

**Purpose:** Run an approved longer experiment with resumable checkpoints, thermal observation, and disk safeguards.

| Setting | Provisional range or policy |
|---|---|
| Image resolution | 224-384 px square, justified by the selected model |
| Batch size | 8-64, experimentally selected below the observed VRAM limit |
| Epochs | 10-50 maximum provisional planning range |
| DataLoader workers | 2-8; cap based on RAM, I/O, and stability measurements |
| Mixed precision | Expected |
| Checkpoint frequency | Every 1-5 epochs and at controlled shutdown/resume points |
| Intended duration category | Longer unattended run; no precise duration assigned |
| Free-space guard | At least 150 GiB before launch and hard stop before 100 GiB |
| Approval requirement | **Explicit user instruction is mandatory before every overnight run** |

Overnight training must never start automatically. A future runner must support resumable checkpoints, bounded retention, failure logging, and safe temperature/disk monitoring before this profile can be accepted for use.
