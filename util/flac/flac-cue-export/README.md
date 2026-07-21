# flac-cue-export

Inverse of `cue-to-flac`: for each album directory with ≥2 FLACs, write a single
image FLAC + CUE sheet (`Album.flac` / `Album.cue`) beside the tracks.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `ffmpeg`, `ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -y    # overwrite existing image/cue
```

Tracks must share sample rate and channel count. The image filename comes from
the `ALBUM` tag (sanitized).

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` `-y` | Shared |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.
