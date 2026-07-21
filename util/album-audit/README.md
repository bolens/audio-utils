# album-audit

Read-only album-level consistency check, one result per directory: track
number gaps and duplicates (per disc), missing track/album tags, mixed
ALBUM / ALBUMARTIST / DATE values, various-artists folders without
ALBUMARTIST, mixed sample rate or bit depth (FLAC), and TOTALTRACKS
mismatches.

Per-file checks live in [`util/flac-audit`](../flac-audit/) and
[`util/lossy-audit`](../lossy-audit/); this tool reasons about the album as a
unit.

Part of **[audio-utils](../../)**.
