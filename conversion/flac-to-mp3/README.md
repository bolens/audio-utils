# flac-to-mp3

FLAC → MP3 via **libmp3lame**, with `flac -t`, duration check (±50ms), and tag/cover copy.

Part of **[audio-utils](../../)**.

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
| `-N` / `--no-resample` | Fail instead of resampling/downmixing |
| `-d` / `-D` | Delete FLAC after success / cleanup-only |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

Exit codes: `0` ok, `1` failures, `2` usage/deps.

## Layout

```
flac-to-mp3.sh, convert-all.sh, find-flac-dirs.sh
lib/  load, quality, encode, convert, cleanup, success_log, worker
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC files to MP3 in one or more directories, with verification.

Verification (per file):
  1. flac -t on source
  2. Encode via libmp3lame (quality profile)
  3. Probe audio stream; duration within ~50ms of source
  4. Tags/cover mapped from FLAC
Existing MP3s that probe OK are skipped; corrupt siblings are reconverted.

Usage:
  flac-to-mp3.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-mp3.sh
  convert-all.sh [options...]

Options:
  -f FILE     Read directory list from FILE
  -d          Delete FLAC after successful conversion
  -D          Cleanup only: delete FLACs that already have a valid sibling MP3
  -Q PROFILE  MP3 quality: v0 (default), v2, 320, 192
  -N          No resample/downmix (fail on unsupported rate/channels)
  -L FILE     Failure log (default: $XDG_STATE_HOME/audio-utils/flac-to-mp3/failures.log)
  -S FILE     Success log CSV or .jsonl
  -n          Dry run
  -y          Overwrite existing MP3s even if probe passes
  -j N        Parallel jobs (default: max(1, nproc/2))
  -q          Quiet
  -v          Verbose
  -h          Help
  --version   Print version
  --quality P Same as -Q
  --no-resample  Same as -N

Quality also via FLAC2MP3_QUALITY or AUDIO_UTILS_MP3_QUALITY (default: v0).

Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
