# flac-audit

Read-only library health check for FLACs under configured roots.

Fails a file when:

- `flac -t` fails
- missing core tags (`ARTIST`, `ALBUM`, `TITLE`, `TRACKNUMBER`)
- no decodable embedded picture or folder cover (`cover.jpg` / `folder.jpg` / …)
- leftover sibling `.wav` / `.aiff` / `.aif` / `.caf` beside the FLAC

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
# Issues land in XDG state failures.log; clean files in success.csv
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

Read-only: `-d`, `-D`, and `-y` are rejected.

Exit codes: `0` all clean, `1` issues found, `2` usage/deps.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Read-only FLAC library audit (integrity, core tags, cover, leftover PCM).

Usage:
  flac-audit.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-audit.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Reports (fails the file) when:
  - flac -t fails
  - missing ARTIST / ALBUM / TITLE / TRACKNUMBER
  - no embedded picture and no folder cover
  - leftover sibling .wav / .aiff / .aif / .caf beside a FLAC

Read-only: -d / -D / -y rejected.
Exit codes: 0 all clean, 1 issues found, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
