# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Collection of small, verified **audio conversion utilities** for Linux libraries. **FLAC** is the archive hub; other lossless formats convert through it.

| Tool | Description |
|------|-------------|
| [`wav-to-flac/`](wav-to-flac/) | Verified WAV → FLAC |
| [`flac-to-wav/`](flac-to-wav/) | Verified FLAC → WAV (bit-depth matched, dual-decode MD5) |
| [`aiff-to-flac/`](aiff-to-flac/) | Verified AIFF/AIF → FLAC |
| [`flac-to-aiff/`](flac-to-aiff/) | Verified FLAC → AIFF (big-endian PCM) |
| [`flac-to-alac/`](flac-to-alac/) / [`alac-to-flac/`](alac-to-flac/) | FLAC ↔ ALAC (`.m4a`, codec-gated) |
| [`flac-to-wv/`](flac-to-wv/) / [`wv-to-flac/`](wv-to-flac/) | FLAC ↔ WavPack (`.wv`; hybrid `.wvc` rejected) |
| [`flac-to-mp3/`](flac-to-mp3/) | FLAC → MP3 (libmp3lame; default VBR **v0**) |

## Quick start

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config"
# edit AUDIO_UTILS_ROOTS

make -C wav-to-flac convert-quiet
make -C aiff-to-flac convert-quiet
make -C flac-to-alac convert-quiet
make -C flac-to-wv convert-quiet
make -C flac-to-mp3 convert-quiet ARGS='-Q v0'
```

## Requirements

- Linux (GNU `find` with `-printf`)
- `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`, coreutils
- **flac-to-mp3**: ffmpeg with `libmp3lame`
- ALAC / WavPack: ffmpeg encoders for `alac` / `wavpack`

## Layout

```
audio-utils/
  lib/          # load, driver, worker, pcm_flac, probe, find-audio-dirs
  <tool>/       # thin CLI + lib/plugin.sh + convert/cleanup/success_log
```

Shared CLI: [`lib/driver.sh`](lib/driver.sh) (`audio_utils_run`) + [`lib/worker.sh`](lib/worker.sh).
PCM↔FLAC helpers: [`lib/pcm_flac.sh`](lib/pcm_flac.sh).

### Plugin contract

Set: `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, optional `AU_SOURCE_EXTS` (space-separated), `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`, `AU_GETOPT_EXTRA`.

Require: `convert_one`, `delete_one_existing`, `init_success_log`, `plugin_require_deps`.

Optional: `plugin_parse_opt`, `plugin_consume_arg`, `plugin_after_flags`, `plugin_banner_extra`, `plugin_export_env`, `plugin_accept_source` (skip non-matching sources, e.g. AAC-in-`.m4a`).

### Paths (XDG)

| Data | Default |
|------|---------|
| Config | `$XDG_CONFIG_HOME/audio-utils/config` |
| Logs | `$XDG_STATE_HOME/audio-utils/<tool>/` |
| Runtime temps | `$XDG_RUNTIME_DIR/audio-utils/` (else cache) |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success (or nothing to do) |
| 1 | One or more conversions/preflight failures |
| 2 | Usage, config, missing deps, or bad arguments |

## Development

```bash
make check
make -C flac-to-alac help
```

## License

[MIT](LICENSE)
