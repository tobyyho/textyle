# Tailor Baseline v0.1 Evaluation Report

The checkpoint was selected only on validation macro-F1. Threshold 0.70 was frozen on validation before the test split was evaluated once; a sentinel prevents an accidental second official evaluation.

## Aggregate metrics

| Split | Accuracy | Macro P | Macro R | Macro F1 | Weighted F1 | Top-3 | ECE (15 bins) | Brier |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Validation | .7836 | .7837 | .7652 | .7673 | .7838 | .9435 | .0362 | .3117 |
| Test | .7971 | .7889 | .7816 | .7827 | .7971 | .9520 | .0270 | .2986 |

## Test per-class metrics

| Class | Precision | Recall | F1 | Support |
|---|---:|---:|---:|---:|
| short_sleeve_top | .8935 | .8835 | .8885 | 266 |
| long_sleeve_top | .6844 | .6816 | .6830 | 245 |
| outerwear | .8423 | .7589 | .7984 | 394 |
| shorts | .8020 | .8495 | .8251 | 186 |
| trousers | .8750 | .8720 | .8735 | 289 |
| skirt | .6817 | .8277 | .7476 | 238 |
| dress | .7432 | .5978 | .6627 | 92 |

## Confidence and latency

At threshold .70, validation accepts 66.83% with .9101 accuracy/.8950 macro-F1; test accepts 70.64% with .9056 accuracy/.8891 macro-F1. Full threshold tables and confusion matrices are in the external run directory. GPU latency: median/p90/p95 3.10/3.24/3.27 ms, 322.87 images/s. CPU (12 threads): 8.23/9.47/9.64 ms, 121.55 images/s. Batch one, deterministic evaluation tensor, warmed, loading excluded.

These are Fashionpedia crop results—not evidence of Textyle-camera performance or production-service latency.
