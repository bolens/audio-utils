# flac-strip

Metadata hygiene: remove `PADDING` and `APPLICATION` blocks, refresh seek
points. Optional `--core-tags` keeps only standard tags; `--no-picture` drops
embedded art.

Part of **[audio-utils](../../)**. See [docs/adding-a-util.md](../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -c          # core tags only
./convert-all.sh -q -c -k       # core tags, no pictures
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-c` / `--core-tags` | Keep only core Vorbis comments |
| `-k` / `--no-picture` | Remove embedded pictures |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.
