# silence-detect

Batch QC: fail on long leading/trailing silence (ffmpeg `silencedetect`) and
optional clipping. Scopes the portable+PCM cluster (`--preset portable-pcm`);
lossless archives (wv/ape/tak/tta) are out of scope unless you pass dirs by hand.
The analysis is a full error-strict decode; unreadable or truncated audio fails
instead of being interpreted as a clean, empty report.

Apply counterpart: [`silence-trim`](../../flac/silence-trim/) (report / `--apply`).
Peer of [`silence-split`](../../flac/silence-split/).

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Detect long leading/trailing silence and clipping.

Usage:
  silence-detect.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --silence-sec=N   Min silence duration (default 1.0)
  --silence-db=N    Noise floor dB (default -50)
  --no-clip         Do not fail on clipping

Read-only: -d / -D / -y rejected.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
