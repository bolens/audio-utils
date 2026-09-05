# flac-cue-export

Inverse of `cue-to-flac`: for each album directory with ≥2 FLACs, write a single
image FLAC + CUE sheet (`Album.flac` / `Album.cue`) beside the tracks.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `ffmpeg`, `ffprobe`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -y    # overwrite existing image/cue
```

Tracks must share sample rate and channel count. The image filename comes from
the `ALBUM` tag (sanitized).

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` `-y` | Shared |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Export album-dir FLACs to a single image FLAC + CUE (inverse of cue-to-flac).

Usage:
  flac-cue-export.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-cue-export.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version

Once per directory with ≥2 FLACs: writes Album.flac + Album.cue beside tracks.
Requires matching sample rate/channels. -y overwrites existing image/cue.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
