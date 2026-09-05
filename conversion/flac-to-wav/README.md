# flac-to-wav

Verified FLAC → WAV (bit-depth matched to source). Dual-decode audio MD5 check, tags/cover copy, smart skip.

Part of **[audio-utils](../../)**.

## Requirements

- Linux, `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
```

PCM output matches source bit depth (16→`pcm_s16le`, 24→`pcm_s24le`, …; unknown→`pcm_s24le`).

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-y` `-f FILE` | Shared (dry-run, quiet, verbose, jobs, overwrite, dir list) |
| `-d` | Delete FLAC after successful convert |
| `-D` | Cleanup only: delete FLACs that already have a valid sibling WAV |
| `-L` / `-S` | Failure / success logs (XDG state defaults) |
| `--version` | Version |

Exit codes: `0` ok, `1` failures, `2` usage/deps.

## Layout

```
flac-to-wav.sh, convert-all.sh, find-flac-dirs.sh
lib/  load, encode, convert, cleanup, success_log, worker
```

Shared infra: [`../../lib/`](../../lib/).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC files to WAV in one or more directories, with verification.

Verification (per file):
  1. flac -t on source
  2. Dual decode to bit-depth-matched PCM; audio MD5 == FLAC audio MD5
  3. Copy tags/cover from FLAC; audio MD5 unchanged
Existing WAVs that probe OK are skipped; corrupt siblings are reconverted.
Temps beside destination (atomic mv); cleaned on EXIT/INT/TERM.

Usage:
  flac-to-wav.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-wav.sh
  convert-all.sh [options...]

Options:
  -f FILE     Read directory list from FILE
  -d          Delete FLAC after successful conversion
  -D          Cleanup only: delete FLACs that already have a valid sibling WAV
  -L FILE     Failure log (default: $XDG_STATE_HOME/audio-utils/flac-to-wav/failures.log)
  -S FILE     Success log CSV or .jsonl
  -n          Dry run
  -y          Overwrite existing WAVs even if probe passes
  -j N        Parallel jobs (default: max(1, nproc/2))
  -q          Quiet
  -v          Verbose
  -h          Help
  --version   Print version

Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
