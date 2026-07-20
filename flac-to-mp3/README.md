# flac-to-mp3

FLAC → MP3 via **libmp3lame**, with `flac -t`, duration check (±50ms), and tag/cover copy.

Part of **[audio-utils](../)**.

## Requirements

- Linux, `bash` 4+, `flac`, `ffmpeg` with **libmp3lame**, `ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q              # default quality: v0 (recommended)
./convert-all.sh -q -Q 320       # CBR 320k
FLAC2MP3_QUALITY=v2 ./convert-all.sh -q
```

## Quality profiles

| Profile | ffmpeg | Notes |
|---------|--------|--------|
| **`v0`** (default) | `-q:a 0` | Best library quality/size — **suggested** |
| `v2` | `-q:a 2` | Smaller |
| `320` | `-b:a 320k` | CBR max |
| `192` | `-b:a 192k` | CBR smaller |

Priority: `-Q` / `--quality` → `FLAC2MP3_QUALITY` → `AUDIO_UTILS_MP3_QUALITY` → `v0`.

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-y` `-f FILE` | Shared |
| `-Q PROFILE` / `--quality` | MP3 quality profile |
| `-d` / `-D` | Delete FLAC after success / cleanup-only |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

Exit codes: `0` ok, `1` failures, `2` usage/deps.

## Layout

```
flac-to-mp3.sh, convert-all.sh, find-flac-dirs.sh
lib/  load, quality, encode, convert, cleanup, success_log, worker
```
