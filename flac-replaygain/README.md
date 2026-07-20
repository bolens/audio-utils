# flac-replaygain

Compute and write ReplayGain 2.0 tags on FLACs. Default is **album + track** per directory (album folder layout). Use `-T` for track-only.

Uses **rsgain** when available, else **loudgain**.

Part of **[audio-utils](../)**. See [docs/adding-a-util.md](../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `flock`
- **rsgain** (preferred) or **loudgain**

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q              # album+track; skip files that already have RG
./convert-all.sh -q -y           # rewrite existing RG
./convert-all.sh -q -T           # track gain only
```

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-T` / `--track` | Track gain only |
| `-y` | Force rewrite (do not skip existing) |
| `-L` / `-S` | Logs (XDG state defaults) |
| `--version` | Version |

`-d` / `-D` are rejected.

Exit codes: `0` ok, `1` failures, `2` usage/deps.
