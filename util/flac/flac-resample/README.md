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
