# lossy-authenticity

Read-only heuristic for lossy re-encodes and “fake high bitrate” files.
Measures mid vs high-frequency RMS and compares the spectral cliff against the
claimed bitrate (e.g. ~320 kbps with a hard wall near 16 kHz).

Not proof — spectrograms and encoder tags still help. Complements
[`lossy-audit`](../lossy-audit/) (tags/cover/bitrate floor) and
[`flac-authenticity`](../../flac/flac-authenticity/) (lossless).

`-s` / `--strict` tightens cliffs and flags common `ffmpeg`/`lavc` encoder
strings on MP3/AAC.

Part of **[audio-utils](../../../)**.

```bash
./lossy-authenticity.sh -n DIR
./lossy-authenticity.sh --strict DIR
make help
```
