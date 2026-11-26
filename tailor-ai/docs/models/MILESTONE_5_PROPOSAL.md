# Proposed Milestone 5 — Textyle-Style Domain Validation and Baseline Hardening

Status: **superseded by Combined Milestones 5–6 execution**.

Based on v0.1 test macro-F1 0.7827, weak dress/long-sleeve performance, context-heavy failures, and overconfident sleeveless predictions, Milestone 5 should:

1. define and collect a small rights-controlled set of fresh laid-flat and hanger images, with article-grouped train/validation/test separation;
2. evaluate v0.1 unchanged on that domain before fine-tuning;
3. establish image-quality and unsupported/OOD evaluation, including sleeveless garments and non-garments;
4. compare targeted augmentation/crop policies and one bounded fine-tuning experiment;
5. freeze a revised threshold using domain validation and evaluate its untouched domain test once.

Keep API, Docker, colour extraction, pattern, front/back fusion, and Flutter integration out of scope unless separately authorized.
