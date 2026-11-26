# Download and Storage Plan

> **Milestone 3 continuation (2026-08-06):** Official downloads occupy 4,185,626,793 bytes, immutable raw images 3,639,453,627 bytes, manifests 140,706,846 bytes, selected crops 706,336,275 bytes, and continuation audit artifacts 3,427,522 bytes. C: retains 1,817,704,243,200 bytes free. The earlier main curl partial was absent at continuation start; its 48,036,647-byte failed-range sidecar remains preserved.

**Planning date:** 2026-08-06  
**Current C: observation:** 1,832.36 GiB total, 1,704.68 GiB available, NTFS fixed drive.

## Approved roots

```text
C:\TextyleData\tailor\data
C:\TextyleData\tailor\artifacts
C:\TextyleData\tailor\cache
```

Proposed dataset layout after authorization:

```text
C:\TextyleData\tailor\cache\downloads\deepfashion2\<version>
C:\TextyleData\tailor\data\raw\deepfashion2\<version>
C:\TextyleData\tailor\data\manifests\deepfashion2\<manifest-version>
C:\TextyleData\tailor\artifacts\experiments\<experiment-id>
```

`D:\TailorArchive` remains an optional future cold-archive location. It is inaccessible to the current project user and is not required for the pilot. Data, images, archives, weights, checkpoints, and caches stay outside Git and OneDrive.

## Free-space gates

- Hard guard: projected and observed free space must remain at least 100 GiB.
- Practical pre-acquisition reserve: keep at least 300 GiB free because archive and extracted files may coexist temporarily.
- Before every transfer/extraction, calculate `current free - remaining download - extraction peak - 20% uncertainty`; stop if the result is below 100 GiB.
- Recheck immediately before and after extraction and before any later training run.

The current 1,704.68 GiB free is ample for the planning budget, but free space is volatile and must be measured again. No capacity observation authorizes a dataset download.

## DeepFashion2 planning budget

The reviewed official sources publish record counts but not archive or extracted byte sizes. The following values are conservative planning estimates, not official facts; replace them with official `Content-Length`/portal values after access and before approval.

| Component | Planning allocation | Treatment |
|---|---:|---|
| Official image archives | 60-120 GiB | Download only after terms approval; exact packaging may force revised scope. |
| Extracted images | 80-160 GiB | Keep one raw extracted copy; no duplicate resized dataset. |
| Annotations/masks/metadata | 1-10 GiB | Prefer obtaining first to inspect counts and grouping. |
| Normalized CSV/JSON manifests | 0.1-2 GiB | Versioned, checksummed; small enough for records, but licence-sensitive content remains outside public sharing. |
| Optional future crops | 0 GiB initially; cap 20 GiB pilot | Generate at runtime first; materialize only if profiling proves necessary. |
| Checkpoints | 2-5 GiB active cap | Best validation plus latest resumable only. |
| Logs/evaluation reports | 1 GiB | Text/metrics, plus a bounded rights-aware error sample. |
| Temporary extraction headroom | 80-160 GiB | Must coexist with archive during verified extraction. |
| Safety reserve | >=100 GiB hard; 300 GiB preferred | Never consume. |

Worst planned simultaneous working allocation excluding reserve is roughly 338-458 GiB. Because official bytes are unknown, any actual requirement outside this range triggers a new approval rather than improvisation.

## Transfer policy

1. Use only the official URL obtained through the authors' access procedure; never substitute a mirror for convenience.
2. Record official source, access/terms status, filename, expected byte size, ETag/last-modified/range support, and destination before starting.
3. Prefer a normal bounded `curl.exe` transfer. For large authorized files, use resumable `--continue-at -` only when the same official endpoint supports range requests.
4. Limit controlled retries (maximum three) with explicit timeouts. Preserve a partial file and logs for diagnosis; do not loop indefinitely.
5. A changed ETag/size or a server ignoring range requests invalidates resume; quarantine the partial file and request review.
6. Hash every completed archive with SHA-256 and compare with an official checksum when available. Where none exists, record size/hash and validate extracted counts/decoding.

Milestone 2's 6.19 MB CVF-paper transfer succeeded normally. It does not eliminate the prior TLS risk for multi-gigabyte transfers. Large acquisitions require resume support and a deliberately small first approved artifact.

## Safe extraction

- Use Windows built-in tools or Python standard library only unless a later archive format demonstrably requires an approved utility.
- List archive members first; reject absolute paths, drive-qualified paths, `..` traversal, links escaping the destination, unexpected executables, and paths outside the verified version directory.
- Extract to a new versioned temporary directory on the same approved root; never overwrite an existing dataset version.
- Verify file count, failure list, sample decodes, annotations, and manifest lineage before declaring extraction complete.
- Retain the source archive until verification and conversion are confirmed. Request user approval before deleting or moving it.

## Cache and artifact policy

- The cache is recoverable but not disposable without user approval when it contains the sole verified archive.
- Disable dataset-wide RAM caching; stream from NVMe. Generate augmentation dynamically.
- Do not prepopulate torchvision weight caches. Future approved weight files use an external recorded cache and checksum.
- Keep only important checkpoints and bounded logs. No automatic cleanup that could remove evidence.

## Integrity and privacy

Record archive SHA-256, extracted-file checksum strategy, manifest SHA-256, mapping/split version, counts, and transformation lineage. Private custom images use the same integrity controls but stricter access and backup approval. Never include credentials or private official download links in reports.
