# perms-normalize

Report (default) or fix (`--apply`) permission modes across the library:
files → `--file-mode` (644), directories → `--dir-mode` (755). Useful after
copying from FAT/NTFS media or across NAS shares. Ownership is never touched.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Report (or fix) file / directory permission modes across the library.

Usage:
  perms-normalize.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --apply             chmod non-conforming files/dirs (default: report-only)
  --file-mode=NNN     Target file mode (default: 644)
  --dir-mode=NNN      Target directory mode (default: 755)

-d / -D / -y rejected. Ownership is not touched.
Exit codes: 0 clean, 1 non-conforming/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
