# spectrogram-export

Render `<file>.spectrogram.png` beside each audio file for manual review —
the human follow-up to [`util/flac-authenticity`](../../flac/flac-authenticity/)
verdicts. Uses `sox spectrogram` for FLAC/WAV/AIFF/CAF when available, ffmpeg
`showspectrumpic` otherwise (`SPECTROGRAM_SIZE`, default `1024x512`).

Part of **[audio-utils](../../../)**.
