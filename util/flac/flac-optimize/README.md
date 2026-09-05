# flac-optimize

Recompress FLACs at a chosen compression level (default **8**) without changing
PCM. Tags and embedded pictures are preserved. Skips when the result is not
smaller unless `-y`.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `ffmpeg`, `ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -c 8 -y    # replace even if not smaller
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` `-y` | Shared |
| `-c N` / `--compression N` | Level `0`–`8` (default `8`) |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Recompress FLACs without changing PCM (default -8).

Usage:
  flac-optimize.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-optimize.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -c N / --compression N   FLAC level 0-8 (default 8)

Skips when the new file is not smaller unless -y.
Preserves Vorbis comments and embedded pictures.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
