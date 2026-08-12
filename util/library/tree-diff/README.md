# tree-diff

Compare files under library roots to the same relative paths in `--against`
(size, optional `--hash`). Useful for backup verification.

Part of **[audio-utils](../../../)**.

## Comparison model

Each scanned source path is made relative to its configured
`AUDIO_UTILS_ROOTS` entry, then looked up beneath `--against`. Default mode
requires the counterpart to exist and have the same byte size. `--hash` also
requires matching SHA-256 content.

```bash
AUDIO_UTILS_ROOTS=/srv/music \
  ./tree-diff.sh --against /mnt/backup/music /srv/music

AUDIO_UTILS_ROOTS=/srv/music \
  ./tree-diff.sh --against /mnt/backup/music --hash /srv/music
```

The explicit source-root mapping matters: without it, the tool refuses to
guess which portion of an absolute path belongs below the comparison root.
Multiple configured roots are supported when each scanned file falls beneath
one of them.

## What it proves

Size comparison is fast but can miss equal-size corruption. `--hash` provides
byte-for-byte verification, including metadata and artwork, at the cost of
reading both trees fully. The scan is one-directional: it reports source files
missing or different in the comparison tree, but does not identify extra files
that exist only under `--against`.

This is read-only; `-d`, `-D`, and `-y` are rejected. Use `--hash` for final
backup verification rather than relying on size alone.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Diff scanned library files against another tree (--against).

Usage:
  tree-diff.sh --against=BACKUP_ROOT DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --against=DIR   Comparison tree (required)
  --hash          Also compare sha256

Relative paths resolved via AUDIO_UTILS_ROOTS.
Read-only: -d / -D / -y rejected.
Exit codes: 0 match, 1 diffs, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
