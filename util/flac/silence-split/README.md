# silence-split

Split long FLAC/WAV/AIFF/CAF files on silence into numbered `.flac` tracks
(`basename - 01.flac`, …). Defaults: silence ≥ 2.0 s at −50 dB; drop segments
shorter than 10 s; write beside the source (or `--outdir`).

Requires at least two keep segments (otherwise fails — use for live sets /
images, not already-split albums). Optional `-d` deletes the source after a
successful split. `-D` is rejected.

Inverse of [`flac-cue-export`](../flac-cue-export/); peer of
[`cue-to-flac`](../../../conversion/cue-to-flac/),
[`silence-detect`](../../audit/silence-detect/), and
[`silence-trim`](../silence-trim/).

Part of **[audio-utils](../../../)**.

```bash
./silence-split.sh -n DIR
./silence-split.sh --silence-sec=1.5 --min-track=20 DIR
make help
```
