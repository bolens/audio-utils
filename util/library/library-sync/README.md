# library-sync

For each FLAC under the archive roots, require a matching portable sibling
(same relative path, `.mp3` / `.opus` / …) under `--portable-root`.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Check each FLAC has a portable sibling under another library root.

Usage:
  library-sync.sh --portable-root=DIR DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --portable-root=DIR   Required portable/lossy library root
  --exts=mp3,opus,m4a   Sibling extensions (default: AU_AUDIO_EXTS_LOSSY)

Requires AUDIO_UTILS_ROOTS (or scanned dirs under it) to resolve relative paths.
Read-only: -d / -D / -y rejected.
Exit codes: 0 ok, 1 missing siblings, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
