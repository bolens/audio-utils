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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
hardlink-dupes - hardlink content-identical FLACs to reclaim space.

Usage:
  hardlink-dupes.sh DIR [DIR ...]
  find-flac-dirs.sh | hardlink-dupes.sh

Options:
  --apply       Replace duplicates with hardlinks to the first keeper
  -M / --md5    Use decode audio MD5 instead of STREAMINFO MD5
  --cross-fs    Attempt link even across filesystems (usually fails)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Report-only by default (exit 1 when candidates exist). Does not support -d/-D/-y.
Prefer flac-dupes for discovery-only; this tool optionally reclaims inodes.
Exit codes: 0 ok, 1 candidates/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
