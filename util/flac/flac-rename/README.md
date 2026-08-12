# flac-rename

Rename FLACs from tags. Default **inplace**: `NN - Title.flac`. Optional
`--layout=artist-album` moves under `DEST/Artist/Album/`.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Rename FLACs from tags (inplace or Artist/Album layout).

Usage:
  flac-rename.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-rename.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  --layout=inplace|artist-album   Default: inplace (NN - Title.flac)
  --dest-root=DIR                 Required for artist-album (or AUDIO_UTILS_ROOTS)

Target name: NN - Title.flac from TRACKNUMBER + TITLE.
artist-album: DEST/Artist/Album/NN - Title.flac
-d / -D rejected. -y overwrites an existing target.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
