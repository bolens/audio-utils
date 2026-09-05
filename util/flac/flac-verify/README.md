# flac-verify

Batch FLAC integrity checks (`flac -t`) under library roots. Optional `-M` adds an independent ffmpeg decode MD5 and compares it to STREAMINFO when present.

Part of **[audio-utils](../../../)**. Non-conversion util — see [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `flock`
- `-M` / `--md5`: also `ffmpeg`, `ffprobe`, `metaflac`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -M          # flac -t + decode MD5
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-M` / `--md5` | Decode MD5 (+ STREAMINFO compare when non-zero) |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

Read-only: `-d`, `-D`, and `-y` are rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.

## Layout

```
flac-verify.sh, convert-all.sh, find-flac-dirs.sh
lib/  plugin, convert, load
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Verify FLAC integrity under library roots (flac -t; optional decode MD5).

Usage:
  flac-verify.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-verify.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -M / --md5   Also decode via ffmpeg and record audio MD5
               (and compare to STREAMINFO MD5 when non-zero)

Read-only: -d / -D / -y are rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
