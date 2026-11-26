# Tailor Baseline v0.1 Sleeveless Probe

> **Tailor baseline v0.1 does not support `sleeveless_top`.**

All 24 held-out sleeveless examples were characterized after the checkpoint and 0.70 threshold were frozen. This is not accuracy evaluation because the model has no sleeveless logit.

- Predicted classes: short_sleeve_top 12, shorts 5, long_sleeve_top 3, dress 2, trousers 1, skirt 1.
- Mean/median confidence: 0.7161/0.7384.
- Rejected at thresholds .50/.60/.70/.75/.80/.90: 3/5/8/14/16/20.
- Eight examples had confidence at least .80. This is dangerously confident unsupported behaviour and confirms that abstention based only on a .70 maximum-softmax threshold is insufficient.

Do not market or expose `sleeveless_top` as supported until it receives authorized training/evaluation data or a reliable unsupported-input mechanism.
