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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
playlist-smart - build a filtered .m3u from tag queries.

Usage:
  playlist-smart.sh --out FILE --genre Rock DIR [DIR ...]
  find-flac-dirs.sh | playlist-smart.sh --out ~/playlists/rock.m3u --genre Rock

Options:
  --out PATH         Destination .m3u (required)
  --genre SUBSTR     Case-insensitive GENRE substring
  --artist SUBSTR    Case-insensitive ARTIST/ALBUMARTIST substring
  --key VALUE        Exact INITIALKEY / KEY (spaces ignored)
  --bpm-min N        Minimum BPM
  --bpm-max N        Maximum BPM
  --rg-max N         Max REPLAYGAIN_TRACK_GAIN (dB; louder tracks excluded)
  --relative         Write paths relative to the playlist directory
  -y                 Overwrite existing --out
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

At least one filter is required. -d/-D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
