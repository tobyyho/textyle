# Milestone 2 Download-Path Test

**Test date:** 2026-08-06  
**Purpose:** Verify a normal TLS transfer from an authoritative research publisher after Milestone 1's large-wheel TLS problems. This is documentation evidence, not dataset acquisition.

| Item | Result |
|---|---|
| Official source | CVF Open Access, original DeepFashion2 CVPR 2019 paper |
| URL | `https://openaccess.thecvf.com/content_CVPR_2019/papers/Ge_DeepFashion2_A_Versatile_Benchmark_for_Detection_Pose_Estimation_Segmentation_and_CVPR_2019_paper.pdf` |
| Public/access gate | HTTP 200 without registration, credentials, form, or terms acceptance |
| Reported `Content-Length` | 6,192,911 bytes |
| Byte-range support | `Accept-Ranges: bytes` reported |
| Destination | `C:\TextyleData\tailor\cache\milestone2_download_test\Ge_DeepFashion2_CVPR_2019_paper.pdf` |
| Normal transfer | Succeeded on first authorized attempt; curl exit code 0 |
| Actual size | 6,192,911 bytes (5.91 MiB) |
| Transfer duration | 3.049 seconds measured by local stopwatch |
| SHA-256 | `2AED78AD11F0F40F3AD21F8155839FAB3CFE0A8EDB81B416E5A269B81736DB75` |
| Resumable test | Not performed because normal transfer succeeded; range support is available if a future authorized transfer needs it |
| Extraction | Not applicable; the file is a PDF, not an archive |
| Total Milestone 2 file-download volume | 6,192,911 bytes |

A sandboxed HEAD attempt could not connect; the same bounded request succeeded with approved network access. No retry loop was used, no partial file remained, and no credentials were exposed. The result demonstrates the normal path for a small file only; it does not prove multi-gigabyte dataset transfers will be reliable.
