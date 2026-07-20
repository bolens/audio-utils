# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Collection of small, verified **audio conversion utilities** for Linux libraries.

| Tool | Description |
|------|-------------|
| [`wav-to-flac/`](wav-to-flac/) | Verified WAV → FLAC (remux, encode checks, tags/cover, cleanup/retag) |

More converters can be added as sibling directories that reuse [`lib/`](lib/).

## Quick start (wav-to-flac)

```bash
# Option A: XDG config (recommended)
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config"
# edit AUDIO_UTILS_ROOTS in that file

# Option B: environment
export AUDIO_UTILS_ROOTS="$HOME/Music $HOME/Downloads"

cd wav-to-flac
./convert-all.sh -n          # dry-run
./convert-all.sh -q          # convert quietly
./convert-all.sh --version
```

Or pass roots explicitly:

```bash
./wav-to-flac/find-wav-dirs.sh ~/Music | ./wav-to-flac/wav-to-flac.sh -n
# same discovery via shared finder:
./lib/find-audio-dirs.sh --ext wav ~/Music
```

## Requirements

- Linux (GNU `find` with `-printf`; see tool README for macOS notes)
- `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`, coreutils

## Layout

```
audio-utils/
  LICENSE
  README.md
  Makefile                 # make check, make wav-to-flac-<target>
  config.example           # AUDIO_UTILS_ROOTS template
  .github/workflows/ci.yml # shellcheck on PRs
  lib/                     # shared: log, xdg, progress, tmpdir, probe, disk, util
    find-audio-dirs.sh     # generic --ext discovery
    load.sh                # source shared modules
    xdg.sh                 # XDG state / cache / runtime paths
  wav-to-flac/             # WAV → FLAC tool (pipeline-only lib/)
```

### Paths (XDG)

| Data | Default |
|------|---------|
| Config | `$XDG_CONFIG_HOME/audio-utils/config` (`~/.config/…`) |
| Logs | `$XDG_STATE_HOME/audio-utils/<tool>/` (`~/.local/state/…`) |
| Runtime temps | `$XDG_RUNTIME_DIR/audio-utils/` (else `$XDG_CACHE_HOME/audio-utils/runtime/`) |
| Album workdirs | `.${AUDIO_UTILS_WORKDIR_PREFIX}.*` beside the media (atomic `mv`) |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success (or nothing to do) |
| 1 | One or more conversions/preflight failures |
| 2 | Usage, config, missing deps, or bad arguments |

### Adding another converter

1. Copy `wav-to-flac/` layout (CLI + `lib/{load,prepare,encode,convert,…}`).
2. In tool `lib/load.sh`, source `../../lib/load.sh`, set `AUDIO_UTILS_WORKDIR_PREFIX=yourtool`.
3. Keep codec/pipeline code local; reuse logging, progress, traps, disk, probes, roots.

## Development

```bash
make check                 # shellcheck shared lib + all tools
make -C wav-to-flac help   # wav-to-flac targets
```

## License

[MIT](LICENSE)
