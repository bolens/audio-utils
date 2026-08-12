# perms-normalize

Report (default) or fix (`--apply`) permission modes across the library:
files → `--file-mode` (644), directories → `--dir-mode` (755). Useful after
copying from FAT/NTFS media or across NAS shares. Ownership is never touched.

Part of **[audio-utils](../../../)**.

## Report-first workflow

Default mode compares encountered files and directories with the requested
ordinary octal modes and reports differences without changing them.

```bash
./perms-normalize.sh /path/to/library
./perms-normalize.sh --file-mode 640 --dir-mode 750 /path/to/library
```

Only three-digit user/group/other modes from `000` through `777` are accepted;
setuid, setgid, and sticky bits are intentionally outside this tool's scope.
Symbolic modes and ACLs are not interpreted.

`--apply` runs `chmod` on mismatches. It does not change ownership, extended
ACLs, xattrs, or file contents. Use dry-run with the final modes before apply,
especially on shared NAS trees where group access matters.

```bash
./perms-normalize.sh -n --apply --file-mode 640 --dir-mode 750 /srv/music
```

The generic `-y`, `-d`, and `-D` flags are rejected; mutation requires the
explicit `--apply` boundary.

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
