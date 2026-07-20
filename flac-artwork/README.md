# flac-artwork

Embed a folder cover (`cover.jpg`, `folder.jpg`, …) into FLACs, or extract embedded pictures to `cover.jpg`.

Part of **[audio-utils](../)**. See [docs/adding-a-util.md](../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q              # embed folder cover when missing
./convert-all.sh -q -y           # replace existing embedded art
./convert-all.sh -q -x           # extract → cover.jpg
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-x` / `--extract` | Export embedded picture to `cover.jpg` |
| `-y` | Overwrite existing embedded art / `cover.jpg` |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` are rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.
