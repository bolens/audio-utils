# Playlists

Local path playlists (not streaming service lists). Shared helpers: [`lib/media/playlist.sh`](../lib/media/playlist.sh). Dependencies: [requirements.md](requirements.md) (core `flac`/`ffmpeg`; optional `iconv` / tags).

## Formats

| Format | Extensions | Notes |
|--------|------------|-------|
| Extended M3U | `.m3u`, `.m3u8` | UTF-8 `#EXTM3U` / `#EXTINF`; `.m3u8` treated as UTF-8 M3U |
| PLS | `.pls` | `[playlist]` `FileN` / `TitleN` / `LengthN` |
| XSPF | `.xspf` | Track `<location>` + optional `<title>`; write uses `file://` for absolute paths |

Default path style when writing: **relative** to the playlist’s directory (portable libraries).

## Tools

| Tool | Role |
|------|------|
| [`util/playlist/playlist-audit/`](../util/playlist/playlist-audit/) | Read-only: missing paths, empty lists, duplicate songs, non-UTF-8 |
| [`util/playlist/playlist-normalize/`](../util/playlist/playlist-normalize/) | Rewrite format and/or `--relative` / `--absolute`; optional `--dedupe` |
| [`util/playlist/playlist-generate/`](../util/playlist/playlist-generate/) | One `.m3u` per audio directory (`<dirname>.m3u` beside tracks) |
| [`util/playlist/playlist-dedupe/`](../util/playlist/playlist-dedupe/) | Drop duplicate entries (keep first); `-y` required to overwrite |
| [`util/playlist/playlist-export/`](../util/playlist/playlist-export/) | Copy referenced tracks to `--dest` and rewrite a relative `.m3u` |

## Song identity (dedupe)

| Mode | Key | Default |
|------|-----|---------|
| `path` | Canonical resolved absolute path | Yes |
| `title` | Normalized artist + title (tags / `#EXTINF` / basename) | `--by title` |

This is playlist entry hygiene — not PCM / chromaprint identity ([`flac-dupes`](../util/flac/flac-dupes/), [`audio-dupes`](../util/audio/audio-dupes/)).

## Examples

```bash
make -C util/playlist/playlist-generate convert-quiet
make -C util/playlist/playlist-audit convert-quiet
make -C util/playlist/playlist-normalize convert-quiet -- --relative
make -C util/playlist/playlist-dedupe convert-quiet -- -y
```

## See also

[docs index](README.md) · [requirements.md](requirements.md) · [formats.md](formats.md) · [adding-a-util.md](adding-a-util.md) · [root README](../README.md) (util table)
