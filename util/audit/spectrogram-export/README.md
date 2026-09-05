# spectrogram-export

Render `<file>.spectrogram.png` beside each audio file for manual review —
the human follow-up to [`util/flac-authenticity`](../../flac/flac-authenticity/)
verdicts. Uses `sox spectrogram` for FLAC/WAV/AIFF/CAF when available, ffmpeg
`showspectrumpic` otherwise (`SPECTROGRAM_SIZE`, default `1024x512`).
Images are decoded for validation and installed atomically, so a failed `-y`
render cannot destroy an existing output.

Part of **[audio-utils](../../../)**.

## Rendering and filenames

The complete source filename is retained in the sidecar name—`song.mp3`
becomes `song.mp3.spectrogram.png`—so adjacent files with different extensions
cannot collide. Set `SPECTROGRAM_SIZE` to change the default `1024x512` image.

```bash
./spectrogram-export.sh -n /path/to/review
SPECTROGRAM_SIZE=1600x800 ./spectrogram-export.sh /path/to/review
```

SoX is preferred for FLAC and PCM containers when installed; FFmpeg's
`showspectrumpic` handles other formats and is the fallback. The image is
rendered to a temporary path, checked as a nonempty decodable image, and moved
atomically. Existing PNGs are skipped unless `-y` is supplied, and a failed
replacement leaves the prior image intact.

A spectrogram is evidence for human review, not an automatic authenticity
verdict. Compare suspicious frequency cutoffs or codec artifacts with the
source history and [`flac-authenticity`](../../flac/flac-authenticity/).

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
