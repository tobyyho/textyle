# Tailor Baseline v0.1 Failure Analysis

Frozen-test review covered the 12 highest-confidence errors and 12 lowest-confidence correct cases. Contact sheets remain outside Git in the run's `failure_analysis` directory.

Recurring patterns observed:

- taxonomy boundaries: shorts/skirt/trousers and outerwear/long-sleeve-top;
- layers and outfits cause the crop to contain several plausible garment cues;
- people, pose, handbags, and scene context influence classification;
- partial/tight crops obscure garment extent and sleeve/body structure;
- graphic tees over visible undershirts and open jackets create sleeve ambiguity;
- highest-confidence errors reach roughly 0.98, so softmax confidence alone is not an OOD guarantee.

The 347 test errors include weak dress recall (0.5978) and confusion that inflates skirt recall at lower precision. Milestone 5 should use fresh laid-flat/hanger imagery and explicit crop/context/OOD analysis, not tune against these test examples.
