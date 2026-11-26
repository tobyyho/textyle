# SAM 2.1 Tiny Compatibility and Quality Probe

**Executed:** 2026-09-13  
**GPU:** NVIDIA GeForce RTX 5080, compute capability 12.0  
**Result:** Compatibility passed; target-quality selection pending

## Measured compatibility results

| Check | Result |
|---|---|
| Model load on RTX 5080 | Pass |
| CUDA inference | Pass |
| Peak allocated VRAM | 424.14 MiB |
| Model load | 0.330 s from warm local cache |
| First CUDA call | 15.46 s one-time kernel/context warm-up |
| Warm per-prompt latency | approximately 17–23 ms on 512×512 synthetic inputs |
| Local-only inference | Pass (`HF_HUB_OFFLINE=1`, `local_files_only=True`) |
| Existing classifier afterward | Pass |
| Tailor automated tests afterward | 42 passed |
| Tailor lint afterward | Pass |
| Package integrity afterward | Pass |

The official checkpoint produced a benign model-type warning when its video-capable configuration was instantiated through `Sam2Model`. The official Transformers documentation demonstrates this image-segmentation use of the same repository. Inference and post-processing completed correctly.

## Controlled garment probes

The test generator provided exact ground-truth masks. Ratings use: Excellent ≥0.95 IoU, Acceptable ≥0.85, Needs retry ≥0.65, Failed <0.65.

| Case | Best IoU | Rating |
|---|---:|---|
| Black garment | 0.9969 | Excellent |
| White garment | 0.9868 | Excellent |
| Patterned garment | 0.9932 | Excellent |
| Sleeves separated from torso | 0.9917 | Excellent |
| Trousers with space between legs | 0.9924 | Excellent |
| Hanger image | 0.9852 | Excellent |
| Laid-flat image | 0.9986 | Excellent |
| Similar-colour background | 0.9893 | Excellent |

These are deterministic synthetic regression cases, not evidence of real-world generalization.

## Permitted real-image stress probes

Twenty-four Fashionpedia validation crops were evaluated without using its held-out test split. These crops mostly show garments worn by people and therefore stress a non-required v1 use case. Ratings below are qualitative inspection of garment isolation, not ground-truth IoU.

| Category / image suffix | Rating | Observation |
|---|---|---|
| dress / `01cd2f` | Acceptable | Dress isolated; boundary includes small person-adjacent detail. |
| dress / `1add73` | Needs retry | Tight crop and body boundary reduce isolation confidence. |
| dress / `ed2a4f` | Acceptable | Main dress retained with mostly coherent edge. |
| long sleeve / `0c7b66` | Acceptable | Sleeved garment retained; person adjacency remains. |
| long sleeve / `1300a6` | Acceptable | Top silhouette retained with tight crop. |
| long sleeve / `8e300d` | Needs retry | Hands/lower body create ambiguous boundary. |
| outerwear / `f06a04` | Needs retry | Open outerwear and inner garment are ambiguous. |
| outerwear / `e5dda8` | Acceptable | Coat silhouette mostly coherent. |
| outerwear / `9f2d74` | Acceptable | Coat retained; tight edge requires caution. |
| short sleeve / `758c1e` | Needs retry | Hair/skin adjacency affects edge. |
| short sleeve / `352cf1` | Needs retry | Arm and shirt boundary is ambiguous. |
| short sleeve / `be2418` | Excellent | Standalone product image isolates cleanly. |
| shorts / `c24716` | Needs retry | Legs merge with the shorts boundary. |
| shorts / `facd70` | Failed | Occluding fabric/person geometry dominates the prompt. |
| shorts / `253280` | Acceptable | Shorts are substantially isolated. |
| skirt / `589abd` | Acceptable | Skirt retained with minor adjacent-person detail. |
| skirt / `ddebb4` | Needs retry | Hands/top adjacency and textured edge interfere. |
| skirt / `6383f8` | Acceptable | Skirt boundary is mostly coherent. |
| sleeveless / `b88b3` | Needs retry | Person silhouette and garment are not cleanly separated. |
| sleeveless / `16c99d` | Failed | Background/arm adjacency produces an unsafe mask. |
| sleeveless / `accc1b` | Needs retry | Garment is retained but person boundary remains. |
| trousers / `805d1f` | Needs retry | Hands and torso are adjacent to trousers. |
| trousers / `4aeaf0` | Failed | Seated pose and furniture make the foreground ambiguous. |
| trousers / `bf230d` | Needs retry | Tight worn-person crop prevents clean isolation. |

Summary: 1 Excellent, 8 Acceptable, 12 Needs retry, 3 Failed. This does not establish failure on Tailor's target scenes, but it does show that deterministic prompting cannot safely support worn-person imagery and that successful inference cannot automatically set readiness.

## Artifact locations

Probe results and images are kept outside Git:

- `C:\TextyleData\tailor\evaluation\milestone-8\sam2-tiny-probe`
- `C:\TextyleData\tailor\evaluation\milestone-8\sam2-real-probe`
- `C:\TextyleData\tailor\cache\huggingface\hub\models--facebook--sam2.1-hiera-tiny`

No dataset, user image, checkpoint, mask, or generated evaluation PNG was added to the repository.

## Gate conclusion

Compatibility is proven and the checkpoint is legally suitable, but permanent technical selection is deferred. Acquire or create a permitted representative target-style evaluation set before implementing the provider, normalization, API, or Flutter persistence work.

