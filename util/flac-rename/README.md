# flac-rename

Rename FLACs from tags. Default **inplace**: `NN - Title.flac`. Optional
`--layout=artist-album` moves under `DEST/Artist/Album/`.

Part of **[audio-utils](../../)**. See [docs/adding-a-util.md](../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q --layout=artist-album --dest-root="$HOME/Music"
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` `-y` | Shared (`-y` overwrite target) |
| `--layout=inplace\|artist-album` | Naming / move mode (default inplace) |
| `--dest-root=DIR` | Library root for `artist-album` |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.
