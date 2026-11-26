# Fashionpedia Acquisition Record

**Initial run:** 2026-08-06  
**Continuation:** 2026-08-06  
**Release:** Fashionpedia 2020 / annotation version 1.0

The user’s browser download initially appeared as `train2020.browser.zip.zip`. It matched the official 3,344,364,592-byte object, passed full ZIP CRC and path-safety inspection, and was renamed to `train2020.browser.zip`. SHA-256: `D896792104A4C35EFA7859A18CF605FDDAE779F5C2372E87E08D7B45949244E2`.

The archive contains 45,623 files under `train/`, with 3,401,013,510 extracted bytes. It contains no unsafe paths, duplicate names, Windows case collisions, or zero-byte members.

The official combined validation/test package `val_test2020.zip` was downloaded in eight bounded 32 MiB ranges with zero failures. It is 236,499,034 bytes with SHA-256 `44EB1685364B6ED6BDA4595FE0DC07A252E9B923112B97B24FF4D440751A2ACC`. It contains 3,200 files under `test/` and 238,440,117 extracted bytes. Only the 1,158 filenames referenced by validation annotations enter manifests; 2,042 test-only images remain raw and unused.

Both archives were extracted into new temporary directories, count/byte reconciled, and moved into new immutable raw directories. Source archives were retained.

At continuation start, the earlier main curl partial `train2020.zip` was no longer present. The 48,036,647-byte unappended `train2020.zip.range.part` remained and was not moved, merged, modified, or deleted. Codex did not remove the missing main partial.
