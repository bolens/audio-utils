# waveform-export

Render `<file>.waveform.png` beside each audio file for visual QC / UI
previews. Uses ffmpeg `showwavespic` (`WAVEFORM_SIZE` default `1920x240`).

Sibling to [`util/audit/spectrogram-export`](../spectrogram-export/).
Images are decoded for validation and installed atomically.

Part of **[audio-utils](../../../)**.

## Rendering and use

The full source name is retained: `track.flac` becomes
`track.flac.waveform.png`. This avoids collisions between same-stem formats and
makes sidecars easy to associate with their source. `WAVEFORM_SIZE` controls
the default `1920x240` canvas and `WAVEFORM_COLORS` controls FFmpeg's waveform
palette.

```bash
./waveform-export.sh -n /path/to/library
WAVEFORM_SIZE=1200x200 ./waveform-export.sh /path/to/library
```

FFmpeg decodes the audio and renders one `showwavespic` frame to a temporary
PNG. The result must be nonempty and decode as an image before atomic
installation. Existing sidecars are retained unless `-y` is passed; failed
rerenders cannot replace a prior valid image.

Waveforms are useful for spotting gross level changes, silence, and edit shape,
but do not measure loudness, clipping, or spectral authenticity on their own.
Use the dedicated dynamics, silence, and spectrogram tools for those questions.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
waveform-export - batch waveform PNGs beside each audio file.

Usage:
  waveform-export.sh DIR [DIR ...]
  find-audio-dirs.sh | waveform-export.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Writes <file>.waveform.png (WAVEFORM_SIZE default 1920x240).
Sibling to spectrogram-export.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
