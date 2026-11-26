# Segmentation Model Selection

**Review date:** 2026-09-13  
**Milestone:** 8  
**Status:** `provisional_primary`; representative quality gate pending

## Current result

SAM 2.1 Tiny passed the local Windows/CUDA compatibility probe and is the Milestone 8 `provisional_primary` implementation. It is **not the permanent or production-validated segmenter** because the available permitted real-image sample is dominated by garments worn by people, while Tailor v1 requires laid-flat and hanger photographs. Engineering may proceed, but production claims remain gated.

## Candidate record

| Candidate | Legal finding | Technical finding | Decision |
|---|---|---|---|
| SAM 2 / SAM 2.1 Tiny | Official Meta code and checkpoints are Apache 2.0. | Native Transformers image inference works on Windows and CUDA without the optional custom kernel. | Leading candidate; quality selection deferred. |
| BRIA RMBG-2.0 | Official checkpoint is CC BY-NC 4.0; commercial use requires a separate agreement. | Not probed. | Rejected to avoid future non-commercial licensing debt. |
| BiRefNet | Repository code is MIT, but official checkpoint terms were not sufficiently explicit for future product use. | Not probed. | Deferred; checkpoint licence must be clarified first. |
| U2-Net | Code licensing alone does not establish the terms of separately distributed pretrained weights. | Not probed. | Deferred; no clearer commercially compatible checkpoint advantage over SAM 2.1 was established. |

## Exact SAM 2.1 Tiny artifact

- Official model: `facebook/sam2.1-hiera-tiny`
- Official Meta checkpoint name: `sam2.1_hiera_tiny.pt`
- Hugging Face repository revision: `de431c4043854a71d8101e17995dfe596bf101a5`
- Parameters reported by the official model card: approximately 39 million
- Local Transformers weight: `model.safetensors`, 155,908,064 bytes
- Locally computed SHA-256: `48c14467e5cf9e51870511feb72c89688e82dd74523142c0538b663e193ac2a7`
- No publisher-supplied checksum was found; the value above is a local integrity record, not an official checksum.

Configuration SHA-256 values computed after acquisition:

| File | SHA-256 |
|---|---|
| `config.json` | `860aff9751b139d83a4ad7df1e5535416fded533e0ead02625edbefcb9953cce` |
| `preprocessor_config.json` | `6ebf229ee259368ce4a8d4f2fe893a72b053023710853e257253939e601f583d` |
| `processor_config.json` | `f8a68e865cfad115c1c2763f3d93eca7b1c622da06da2a9273eb437fb2389b6d` |
| `video_preprocessor_config.json` | `9fccfe5f464ec38c2f236d0e6a68e95511c80c22132fc2fa4b9f7b65f24fad95` |

## Compatibility

Meta's native repository requires Python 3.10 or newer, PyTorch 2.5.1 or newer, and torchvision 0.20.1 or newer. Tailor uses Python 3.12.10, PyTorch 2.13.0+cu130, and torchvision 0.28.0+cu130. Meta recommends WSL for the native repository on Windows because its optional CUDA extension can be difficult to compile. This probe instead used the official Transformers SAM 2 implementation, which is pure PyTorch for this path and did not compile or install a custom CUDA extension.

Minimum added direct dependency: `transformers==5.17.0`. No PyTorch, torchvision, CUDA, driver, cuDNN, or classifier dependency was replaced or downgraded.

## Foreground prompting and mask selection

SAM 2 does not identify “the garment” automatically. The evaluated deterministic local strategy was:

1. estimate the border colour from the image perimeter;
2. derive a coarse foreground map from colour distance;
3. derive a padded foreground bounding box;
4. add positive points near the foreground centre and strongest contrast, plus negative corner points;
5. request SAM's multimask output;
6. rank candidates using SAM's predicted IoU, agreement with the coarse foreground map, and a conservative foreground-area sanity term;
7. reject or request retry when later sanity checks fail.

Box-only prompting was also measured. It was sometimes marginally better on simple silhouettes, so the production abstraction must retain candidate scoring instead of assuming more prompts are always better.

No external inference occurred. After the initial checkpoint download, both probes used `local_files_only=True` with Hugging Face offline mode enabled.

## Selection gate

SAM 2.1 Tiny may be promoted only after a permitted target-style set includes enough representative laid-flat and hanger photographs to cover black, white, patterned, separated sleeves, trouser gaps, similar-colour backgrounds, clutter, and camera variation. Synthetic cases are useful regression tests but do not replace real capture validation.

## Authoritative references

- [Meta SAM 2 repository and Apache 2.0 checkpoint statement](https://github.com/facebookresearch/sam2)
- [Official SAM 2.1 Tiny model card](https://huggingface.co/facebook/sam2.1-hiera-tiny)
- [Official Transformers SAM 2 documentation](https://huggingface.co/docs/transformers/model_doc/sam2)
