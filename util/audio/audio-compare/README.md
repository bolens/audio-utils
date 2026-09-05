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

## Root mapping and mode choice

Each source path is resolved relative to its configured `AUDIO_UTILS_ROOTS`
entry and mapped beneath `--against`; the tool refuses to guess a source root.

```bash
AUDIO_UTILS_ROOTS=/srv/archive \
  ./audio-compare.sh --against /mnt/copy /srv/archive
```

Decoded `md5` is the strongest cross-container equality check for integer PCM.
`streaminfo` is faster but requires nonzero FLAC STREAMINFO MD5 values on both
sides. `peak` only compares absolute peak within the selected epsilon; matching
peaks do not imply matching waveforms and are best used as a coarse diagnostic.

This is a one-directional, read-only comparison. It reports missing counterparts
and mismatches but not files found only in the comparison tree. Use `tree-diff`
for byte identity and reverse scans for surplus detection.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
audio-compare - bit-identical / PCM MD5 / peak-diff vs an against tree.

Usage:
  audio-compare.sh --against=DIR DIR [DIR ...]
  find-audio-dirs.sh | audio-compare.sh --against=DIR

Options:
  --against=DIR     Mirror tree to compare against (required)
  --mode=md5|streaminfo|peak   Default md5 (ffmpeg decode MD5)
  --peak-eps=N      Max abs peak delta for --mode=peak (default 0.001)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Requires AUDIO_UTILS_ROOTS so relative paths can be mirrored under --against.
-d / -D rejected.
Exit codes: 0 ok, 1 mismatches, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
