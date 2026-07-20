# audio-replaygain

ReplayGain 2.0 for FLAC and common portable formats (MP3 / Opus / M4A / Ogg /
WMA / MPC) via **rsgain** or **loudgain**.

Part of **[audio-utils](../../)**. See [docs/adding-a-util.md](../../docs/adding-a-util.md).

## Requirements

- `rsgain` (preferred) or `loudgain`, `ffmpeg`/`ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -T    # track only
```
