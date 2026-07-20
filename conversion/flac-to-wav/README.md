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
