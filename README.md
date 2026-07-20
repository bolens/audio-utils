# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Collection of small, verified **audio conversion utilities** for Linux libraries.

| Tool | Description |
|------|-------------|
| [`wav-to-flac/`](wav-to-flac/) | Verified WAV → FLAC (remux, encode checks, tags/cover, cleanup/retag) |
| [`flac-to-wav/`](flac-to-wav/) | Verified FLAC → WAV (bit-depth matched, dual-decode MD5, tags) |
| [`flac-to-mp3/`](flac-to-mp3/) | FLAC → MP3 (libmp3lame; default VBR **v0**; duration/tag checks) |

More converters can be added as sibling directories that reuse [`lib/`](lib/).

## Quick start

```bash
# Config (recommended)
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config"
# edit AUDIO_UTILS_ROOTS

# WAV → FLAC
make -C wav-to-flac convert-quiet

# FLAC → WAV (PCM matches source bit depth)
make -C flac-to-wav convert-quiet

# FLAC → MP3 (suggested quality: v0)
make -C flac-to-mp3 convert-quiet
make -C flac-to-mp3 convert-quiet ARGS='-Q 320'
```

Or:

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music $HOME/Downloads"
./wav-to-flac/convert-all.sh -q
./flac-to-wav/convert-all.sh -q
./flac-to-mp3/convert-all.sh -q -Q v0
```

## Requirements

- Linux (GNU `find` with `-printf`)
- `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`, coreutils
- **flac-to-mp3**: ffmpeg built with `libmp3lame`

## Layout

```
audio-utils/
  LICENSE, README.md, VERSION, Makefile, config.example
  lib/                     # shared helpers + find-audio-dirs.sh
  wav-to-flac/
  flac-to-wav/
  flac-to-mp3/
```

### Paths (XDG)

| Data | Default |
|------|---------|
| Config | `$XDG_CONFIG_HOME/audio-utils/config` |
| Logs | `$XDG_STATE_HOME/audio-utils/<tool>/` |
| Runtime temps | `$XDG_RUNTIME_DIR/audio-utils/` (else cache) |
| Album workdirs | `.${AUDIO_UTILS_WORKDIR_PREFIX}.*` beside media |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success (or nothing to do) |
| 1 | One or more conversions/preflight failures |
| 2 | Usage, config, missing deps, or bad arguments |

### Adding another converter

1. Copy an existing tool layout (CLI + `lib/{load,encode,convert,…}`).
2. In tool `lib/load.sh`, source `../../lib/load.sh`, set `AUDIO_UTILS_WORKDIR_PREFIX=yourtool`.
3. Keep codec/pipeline code local; reuse logging, progress, traps, disk, probes, roots.
4. Wire `make check` and a `tool-%` delegate in the root Makefile.

## Development

```bash
make check
make -C flac-to-mp3 help
```

## License

[MIT](LICENSE)
