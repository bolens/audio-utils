# junk-cleanup

Find OS litter beside audio: `Thumbs.db`, `desktop.ini`, `.DS_Store`,
`.directory`, AppleDouble `._*` files, and zero-byte files. Report-only by
default (exit 1 when junk is found); `-d` deletes.

Companion to [`util/pcm-cleanup`](../pcm-cleanup/) (leftover PCM).

Part of **[audio-utils](../../../)**.

## Classification

The scanner queues only known OS-generated names and zero-byte files. Ordinary
audio and sidecar files are included in discovery so empty files can be found,
but nonempty files outside the junk-name rules are skipped.

```bash
./junk-cleanup.sh /path/to/library
./junk-cleanup.sh -n -d /path/to/library
```

Default mode reports findings and exits `1`; this makes it useful as a hygiene
check in scheduled audits. `-d` removes exactly the classified findings. `-D`
and `-y` are rejected because there is no sibling-verification workflow.

Zero-byte files deserve particular review: an empty audio or metadata file may
represent failed copying rather than harmless OS litter. Always inspect a dry
run and maintain a backup before applying deletion. Empty directories are a
separate concern handled by [`empty-dirs`](../empty-dirs/).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Report (or delete) junk files: Thumbs.db, desktop.ini, .DS_Store,
.directory, AppleDouble ._*, zero-byte files.

Usage:
  junk-cleanup.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -d              Delete junk (default: report-only, exit 1 when junk found)

-D / -y rejected.
Exit codes: 0 clean, 1 junk found/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
