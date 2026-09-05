# playlist-audit

Read-only playlist health check: UTF-8, resolvable entry paths, empty lists, and duplicate songs (`--by path|title`).

Supports `.m3u` / `.m3u8`, `.pls`, `.xspf`.

Part of **[audio-utils](../../../)**. See [docs/playlists.md](../../../docs/playlists.md).

## Checks and identity modes

The audit validates UTF-8 when `iconv` is present, detects the actual playlist
format, parses all entries, rejects empty playlists, and reports unreadable or
missing targets. Duplicate detection defaults to canonical resolved paths.
`--by title` uses normalized artist/title identity and is deliberately softer.

```bash
./playlist-audit.sh /path/to/playlists
./playlist-audit.sh --by title /path/to/playlists
```

One playlist can report several findings together, such as
`non-utf8;missing=2;dupes=1`. A clean result means every listed local path is
readable and no selected-identity duplicates exist; it does not decode every
audio file or validate remote playlist URLs.

This tool is read-only and rejects `-d`, `-D`, and `-y`. Use
[`playlist-normalize`](../playlist-normalize/) for format/path repair and
[`playlist-dedupe`](../playlist-dedupe/) for controlled rewriting. See
[playlist behavior](../../../docs/playlists.md).

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
