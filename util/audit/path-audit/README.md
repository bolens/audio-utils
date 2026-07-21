# path-audit

Read-only filename portability audit: FAT/exFAT/NTFS-illegal characters,
control characters, trailing dots/spaces, reserved DOS names, components over
255 bytes, non-UTF-8 names. Parent directory names are checked once per
directory. `--max-path=N` adds a full-path byte-length check (e.g. 260 for
Windows targets).

Fix offenders with [`util/flac-rename`](../../flac/flac-rename/) or by hand.

Part of **[audio-utils](../../../)**.
