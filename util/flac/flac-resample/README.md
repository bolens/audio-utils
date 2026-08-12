# flac-resample

Intentional FLAC sample-rate / bit-depth conversion (e.g. 96/24 → 48/24 or
44.1/16). Report-only by default; `--apply` rewrites in place and restores
tags + cover via `tag_flac_from_source`.

| Flag | Meaning |
|------|---------|
| `--rate=Hz` | Target sample rate |
| `--bits=16\|24` | Target bit depth |
| `--apply` | Write (default: fail candidates) |
| `--allow-upsample` | Allow increasing rate/depth |

Default policy is **down only** — files already at or below the target are
skipped. Pairs with [`flac-authenticity`](../flac-authenticity/) hi-res verdicts.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
flac-resample - intentional downsample / bit-depth change for archive FLACs.

Usage:
  flac-resample.sh --rate=44100 [--bits=16] DIR [DIR ...]
  find-flac-dirs.sh | flac-resample.sh --rate=48000 --apply

Options:
  --rate=Hz         Target sample rate (e.g. 44100, 48000)
  --bits=16|24      Target bit depth
  --apply           Rewrite in place (default: report candidates as failures)
  --allow-upsample  Permit increasing rate/depth (default: down only)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Pairs with flac-authenticity “fake hi-res” findings. Preserves tags + art.
-d / -D rejected.
Exit codes: 0 ok, 1 candidates (report) or apply failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
