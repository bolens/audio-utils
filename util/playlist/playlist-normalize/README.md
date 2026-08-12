# playlist-normalize

Rewrite playlists: change format (`--format m3u|pls|xspf`), path style (`--relative` / `--absolute`), and optionally drop duplicates (`--dedupe`).

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

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
