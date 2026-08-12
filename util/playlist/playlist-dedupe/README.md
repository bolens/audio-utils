# playlist-dedupe

Rewrite playlists dropping duplicate songs (keeps the first occurrence). Default identity is canonical path; use `--by title` for soft artist+title matching. Pass `-y` to overwrite when duplicates exist.

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

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
