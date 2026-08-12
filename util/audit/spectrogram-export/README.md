# spectrogram-export

Render `<file>.spectrogram.png` beside each audio file for manual review —
the human follow-up to [`util/flac-authenticity`](../../flac/flac-authenticity/)
verdicts. Uses `sox spectrogram` for FLAC/WAV/AIFF/CAF when available, ffmpeg
`showspectrumpic` otherwise (`SPECTROGRAM_SIZE`, default `1024x512`).
Images are decoded for validation and installed atomically, so a failed `-y`
render cannot destroy an existing output.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Export spectrogram PNGs beside audio files (sox preferred, ffmpeg fallback).

Usage:
  spectrogram-export.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -y              Overwrite existing .spectrogram.png

-d / -D rejected. Output: <file>.spectrogram.png beside the source.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
