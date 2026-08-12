# waveform-export

Render `<file>.waveform.png` beside each audio file for visual QC / UI
previews. Uses ffmpeg `showwavespic` (`WAVEFORM_SIZE` default `1920x240`).

Sibling to [`util/audit/spectrogram-export`](../spectrogram-export/).
Images are decoded for validation and installed atomically.

Part of **[audio-utils](../../../)**.

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
```
<!-- END GENERATED COMMAND REFERENCE -->
