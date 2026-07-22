# multi-disc-layout

Normalize multi-disc albums into `Disc N/` subfolders from `DISCNUMBER` /
`TOTALDISCS` tags. Report-only by default; `--apply` moves files.

An album is multi-disc when any track has `DISCNUMBER>1` or `TOTALDISCS>1`.
Single-disc albums stay flat. Folder prefix defaults to `Disc` (`--prefix`).

Companion to [`util/flac/flac-rename`](../../flac/flac-rename/) (filenames) and
[`util/audit/album-audit`](../../audit/album-audit/) (track gaps).

Part of **[audio-utils](../../../)**.
