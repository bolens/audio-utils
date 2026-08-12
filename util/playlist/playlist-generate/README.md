# playlist-generate

Build one `.m3u` per audio-containing directory (named after the folder, beside the tracks). Relative paths, `#EXTINF` from tags when available, path-deduped.

Use `-y` to overwrite an existing playlist.

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Generate one .m3u per audio-containing directory (beside tracks).

Usage:
  playlist-generate.sh DIR [DIR ...]

Options:
  -y  overwrite existing .m3u
  -n  -j N  -q  -v  -h  --version  -f/-L/-S

-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
