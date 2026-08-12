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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
silence-split - split long audio on silence into numbered FLAC tracks.

Usage:
  silence-split.sh DIR [DIR ...]
  find-flac-dirs.sh | silence-split.sh

Options:
  --silence-sec SEC   Minimum silence length to split on (default 2.0)
  --silence-db DB     Noise floor for silence (default -50)
  --min-track SEC     Drop segments shorter than this (default 10)
  --outdir DIR        Write tracks here (default: beside source)
  -d                  Delete source after a successful multi-track split
  -y                  Overwrite existing track files
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Requires at least 2 keep segments. Inverse of flac-cue-export / peer of cue-to-flac.
```
<!-- END GENERATED COMMAND REFERENCE -->
