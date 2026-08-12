# flac-dupes

Find content-identical FLACs under library roots. Default key is STREAMINFO
MD5; optional decode MD5 or chromaprint fingerprint (exact match).

First path per key is “unique”; later matches fail the run.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`
- `-M` / `--md5`: `ffmpeg`, `ffprobe`
- `--fingerprint`: **fpcalc** (chromaprint)

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -M
./convert-all.sh -q --fingerprint
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-M` / `--md5` | Decode audio MD5 instead of STREAMINFO |
| `--fingerprint` | Exact chromaprint match (`fpcalc`) |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

Read-only: `-d`, `-D`, and `-y` are rejected.

Exit codes: `0` no dupes, `1` dupes/failures, `2` usage/deps.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Find content-duplicate FLACs under library roots.

Usage:
  flac-dupes.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-dupes.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -M / --md5            Use ffmpeg decode MD5 instead of STREAMINFO
  --fingerprint         Chromaprint fpcalc (exact fingerprint match)

First file per content key succeeds; later matches fail (exit 1).
Read-only: -d / -D / -y rejected.
Exit codes: 0 no dupes, 1 dupes/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
