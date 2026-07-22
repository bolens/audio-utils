# playlist-smart

Build one filtered `.m3u` from tag queries across scanned roots. Requires
`--out PATH` and at least one of `--genre`, `--artist`, `--key`, `--bpm-min`,
`--bpm-max`, `--rg-max`.

Matches are collected during the run; `plugin_finalize` writes the playlist
(absolute paths by default, `--relative` for paths beside the `.m3u`). Use `-y`
to overwrite an existing `--out`.

Pairs with [`audio-bpm`](../../audio/audio-bpm/), [`audio-key`](../../audio/audio-key/),
and [`flac-replaygain`](../../flac/flac-replaygain/) for tag sources, and
[`playlist-generate`](../playlist-generate/) for per-directory lists.

Part of **[audio-utils](../../../)**.

```bash
./playlist-smart.sh --out /tmp/rock.m3u --genre Rock DIR
./playlist-smart.sh --out /tmp/fast.m3u --bpm-min 120 --bpm-max 140 DIR
make help
```
