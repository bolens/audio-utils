# flac-tags

Normalize Vorbis comments on FLACs under library roots: uppercase keys, trim
values, zero-pad `TRACKNUMBER`, normalize `DATE`, strip iTunes/encoder junk.

Part of **[audio-utils](../../)**. See [docs/adding-a-util.md](../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -A          # also fill ALBUMARTIST from ARTIST
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` `-y` | Shared (`-y` force rewrite) |
| `-A` / `--fill-albumartist` | Set `ALBUMARTIST` from `ARTIST` when missing |
| `-k` / `--keep-encoder` | Keep `ENCODER` / `TOOL` / `RIPPER`-like tags |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` rejected. Pictures are preserved.

Exit codes: `0` ok, `1` failures, `2` usage/deps.
