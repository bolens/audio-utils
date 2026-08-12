# playlist-audit

Read-only playlist health check: UTF-8, resolvable entry paths, empty lists, and duplicate songs (`--by path|title`).

Supports `.m3u` / `.m3u8`, `.pls`, `.xspf`.

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit playlist files (missing paths, empty, duplicates, UTF-8).

Usage:
  playlist-audit.sh DIR [DIR ...]

Options:
  --by path|title   Duplicate identity (default: path)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
