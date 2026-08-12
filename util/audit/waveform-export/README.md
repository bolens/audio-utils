# waveform-export

Render `<file>.waveform.png` beside each audio file for visual QC / UI
previews. Uses ffmpeg `showwavespic` (`WAVEFORM_SIZE` default `1920x240`).

Sibling to [`util/audit/spectrogram-export`](../spectrogram-export/).
Images are decoded for validation and installed atomically.

Part of **[audio-utils](../../../)**.
