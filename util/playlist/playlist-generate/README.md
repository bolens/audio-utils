# playlist-generate

Build one `.m3u` per audio-containing directory (named after the folder, beside the tracks). Relative paths, `#EXTINF` from tags when available, path-deduped.

Use `-y` to overwrite an existing playlist.

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

## Directory behavior

Although discovery visits audio files, generation is coordinated once per
directory with a lock and session marker. A directory named `Album` receives
`Album.m3u` beside its tracks. Entries are sorted by the shared playlist helper,
deduplicated by path, and written relative to that directory.

```bash
./playlist-generate.sh -n /path/to/music
./playlist-generate.sh /path/to/music
```

When metadata tools are available, `#EXTINF` lines include duration and title;
otherwise a valid path-only M3U is still produced. Subdirectories receive their
own playlists rather than being flattened into the parent.

Existing playlists are retained unless `-y` is passed. Use dry-run before a
broad overwrite, because generation replaces the tool-named playlist rather
than merging hand-curated ordering. Audio is never modified or deleted, and
`-d`/`-D` are rejected. See
[playlist behavior](../../../docs/playlists.md).

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
