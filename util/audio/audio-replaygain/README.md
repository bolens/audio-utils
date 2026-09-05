# audio-replaygain

ReplayGain 2.0 for FLAC and the portable cluster (`AU_AUDIO_EXTS_DEFAULT`:
MP3 / Opus / M4A / Ogg / WMA / MPC / Speex / AAC) via **rsgain** or **loudgain**.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- `rsgain` (preferred) or `loudgain`, `ffmpeg`/`ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -T    # track only
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
ReplayGain for FLAC and common lossy formats (rsgain/loudgain).

Usage:
  audio-replaygain.sh DIR [DIR ...]
  find-audio-dirs.sh | audio-replaygain.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -T / --track   Track gain only (default: album+track)

-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
