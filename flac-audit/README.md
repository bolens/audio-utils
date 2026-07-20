# flac-audit

Read-only library health check for FLACs under configured roots.

Fails a file when:

- `flac -t` fails
- missing core tags (`ARTIST`, `ALBUM`, `TITLE`, `TRACKNUMBER`)
- no embedded picture **and** no folder cover (`cover.jpg` / `folder.jpg` / …)
- leftover sibling `.wav` / `.aiff` / `.aif` beside the FLAC

Part of **[audio-utils](../)**. See [docs/adding-a-util.md](../docs/adding-a-util.md).

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
