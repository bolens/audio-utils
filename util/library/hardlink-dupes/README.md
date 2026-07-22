# hardlink-dupes

Find content-identical FLACs (STREAMINFO MD5 by default, or `-M`/`--md5`
decode MD5) and optionally replace duplicates with hardlinks to the first
keeper inode (`--apply`).

Report-only by default (candidates exit 1). Skips paths already sharing an
inode. Cross-filesystem duplicates fail unless `--cross-fs` (hardlink still
requires same FS).

Complements [`flac-dupes`](../../flac/flac-dupes/) (report only) by reclaiming
space without deleting files.

Part of **[audio-utils](../../../)**.

```bash
./hardlink-dupes.sh -n DIR
./hardlink-dupes.sh --apply DIR
make help
```
