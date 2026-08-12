# dsf-to-flac

DSD Stream File (`.dsf`) / DSDIFF (`.dff`) → FLAC.

Decodes to PCM at **88200 Hz / 24-bit** by default (`AUDIO_UTILS_DSD_RATE`).
`.dff` may need **sox** when ffmpeg lacks a DSDIFF demuxer.

Part of **[audio-utils](../../)**. See also [docs/dsd.md](../../docs/dsd.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert DSD (DSF/DFF) -> FLAC via PCM downsample.

Default PCM rate: 88200 Hz / 24-bit (override: AUDIO_UTILS_DSD_RATE).
DFF: ffmpeg first; sox fallback if demuxer missing.

Usage:
  dsf-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | dsf-to-flac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
