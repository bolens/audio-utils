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
  lib/                     # shared helpers, driver, worker, find-audio-dirs
  wav-to-flac/             # thin CLI + lib/plugin.sh + codec modules
  flac-to-wav/
  flac-to-mp3/
```

Shared CLI lives in [`lib/driver.sh`](lib/driver.sh) (`audio_utils_run`) and [`lib/worker.sh`](lib/worker.sh). Each tool is a plugin: set contract vars, implement `convert_one` / `delete_one_existing` / `init_success_log`, optional flag hooks.

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

1. Copy a sibling tool dir; keep codec code in `lib/{encode,convert,cleanup,…}.sh`.
2. Write `lib/plugin.sh`: set `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`, optional `AU_GETOPT_EXTRA`; source `../../lib/load.sh` and local modules; define `plugin_require_deps` and optional `plugin_parse_opt` / `plugin_consume_arg` / `plugin_after_flags` / `plugin_banner_extra` / `plugin_export_env`.
3. Thin CLI: set `AU_USAGE_*`, `source lib/plugin.sh`, `source ../lib/driver.sh`, `audio_utils_load_config`, `audio_utils_run "$@"`.
4. Wire `make check` and a `tool-%` delegate in the root Makefile.

## Development

```bash
make check
make -C flac-to-mp3 help
```

## License

[MIT](LICENSE)
