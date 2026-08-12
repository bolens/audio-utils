# library-prune

Inverse of [`util/library-sync`](../library-sync/): for each portable lossy
file, require a master (same relative path, `--exts`, default `.flac`) under
`--flac-root`. Orphans — portable files whose master was deleted or renamed —
are reported (exit 1) or deleted with `-d`.

Part of **[audio-utils](../../../)**.

## Root mapping

Portable paths are interpreted relative to `--portable-root` when supplied,
then mapped beneath `--flac-root`. `--exts` controls acceptable master
extensions and defaults to `flac`.

```bash
./library-prune.sh --portable-root /srv/portable \
  --flac-root /srv/archive /srv/portable
./library-prune.sh -n -d --portable-root /srv/portable \
  --flac-root /srv/archive /srv/portable
```

## Deletion boundary

Default mode reports every portable file whose relative stem has no master and
returns exit status `1`. With `-d`, those reported portable files are deleted.
The check is intentionally structural: it does not search by tags, hashes, or
audio fingerprint, so a renamed or reorganized master makes the old portable
path appear orphaned.

Always run `-n -d` and inspect root mappings before applying deletion. `-D` and
`-y` are rejected. This tool cleans derivative libraries only; never point the
portable root at the archive master. See the forward completeness check in
[`library-sync`](../library-sync/).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Find portable files whose FLAC master no longer exists (inverse of
library-sync). Report-only by default; -d deletes orphans.

Usage:
  library-prune.sh --flac-root DIR PORTABLE_DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --flac-root=DIR       FLAC archive root (required)
  --portable-root=DIR   Portable root (default: matching AUDIO_UTILS_ROOTS)
  --exts=LIST           Master extensions to accept (default: flac)
  -d                    Delete orphaned portable files

-D / -y rejected.
Exit codes: 0 clean, 1 orphans/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
