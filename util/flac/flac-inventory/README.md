# flac-inventory

Read-only library report: sample-rate / bit-depth / channel histograms, total
bytes and duration, ReplayGain and embedded-art coverage. Prints a summary and
writes `inventory-report.txt` under XDG state.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `ffmpeg`, `ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

Read-only: `-d`, `-D`, and `-y` are rejected.

Exit codes: `0` ok, `1` integrity failures, `2` usage/deps.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Library inventory: sample rate, bit depth, RG, art, size totals.

Usage:
  flac-inventory.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-inventory.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Writes a summary report under XDG state (inventory-report.txt).
Read-only: -d / -D / -y rejected.
Exit codes: 0 ok, 1 integrity failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
