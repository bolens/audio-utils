# audio-compare

Compare each scanned file to the same relative path under `--against`
(requires `AUDIO_UTILS_ROOTS`). Modes:

| `--mode` | Check |
|----------|--------|
| `md5` (default) | ffmpeg decode audio MD5 |
| `streaminfo` | FLAC STREAMINFO MD5 (both sides FLAC) |
| `peak` | abs peak delta ≤ `--peak-eps` (default `0.001`) |

Read-only. Companion to [`util/library/tree-diff`](../../library/tree-diff/)
(file presence/hash) for PCM-level checks.

Part of **[audio-utils](../../../)**.
