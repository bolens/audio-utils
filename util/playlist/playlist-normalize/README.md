# playlist-normalize

Rewrite playlists: change format (`--format m3u|pls|xspf`), path style (`--relative` / `--absolute`), and optionally drop duplicates (`--dedupe`).

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

## Format and path conversion

Without `--format`, the detected playlist family is retained and rewritten in
place. Selecting another family writes a sibling with the appropriate
extension; an existing destination is skipped unless `-y` is supplied.
Supported output families are M3U/M3U8, PLS, and XSPF.

```bash
./playlist-normalize.sh -n --relative /path/to/playlists
./playlist-normalize.sh --format xspf --absolute /path/to/playlists
```

Relative paths are based on the source playlist directory, including when a
new-format sibling is produced. Absolute mode resolves local entries to full
paths. Format conversion preserves entry order and the metadata representable
by the destination format.

## Optional deduplication

`--dedupe` keeps the first occurrence. `--by path` uses resolved path identity;
`--by title` uses normalized artist/title metadata and may merge distinct
recordings with the same labels.

```bash
./playlist-normalize.sh --dedupe --by path -n /path/to/playlists
```

Normalization writes playlists but never deletes audio or source playlists;
`-d`/`-D` are rejected. Use dry-run before changing path style or using soft
title matching. See [playlist behavior](../../../docs/playlists.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Rewrite playlists: format and/or relative<->absolute paths; optional dedupe.

Usage:
  playlist-normalize.sh DIR [DIR ...]

Options:
  --format m3u|m3u8|pls|xspf   Output format (default: same as input)
  --relative              Paths relative to playlist dir (default)
  --absolute              Absolute paths
  --dedupe                Drop duplicate entries while rewriting
  --by path|title         Dedupe identity when --dedupe (default: path)
  -y  -n  -j N  -q  -v  -h  --version  -f/-L/-S

-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
