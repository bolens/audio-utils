# playlist-dedupe

Rewrite playlists dropping duplicate songs (keeps the first occurrence). Default identity is canonical path; use `--by title` for soft artist+title matching. Pass `-y` to overwrite when duplicates exist.

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

## Identity choices

Default `--by path` resolves entries relative to the playlist and compares
canonical paths. `--by title` instead derives a normalized artist/title key
from playlist metadata or audio tags, allowing differently located copies to
collide. Title matching is intentionally softer and deserves manual review.

```bash
./playlist-dedupe.sh -n /path/to/playlists
./playlist-dedupe.sh --by title -n /path/to/playlists
```

## Rewrite safety

Duplicates are reported without modifying the playlist unless `-y` is passed.
When rewriting, the first occurrence is retained, original ordering is
preserved, and the playlist is written in its detected M3U, PLS, or XSPF
format with relative paths. A playlist with no duplicates is left untouched.

```bash
./playlist-dedupe.sh -y /path/to/playlists
```

The tool does not delete audio or playlist source files and rejects `-d`/`-D`.
Keep a versioned or backed-up copy before using title-based rewrites across a
large collection. See [playlist behavior](../../../docs/playlists.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Rewrite playlists dropping duplicate songs (keep first).

Usage:
  playlist-dedupe.sh DIR [DIR ...]

Options:
  --by path|title   Duplicate identity (default: path)
  -y                Required to overwrite playlists that have dupes
  -n  -j N  -q  -v  -h  --version  -f/-L/-S

-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
