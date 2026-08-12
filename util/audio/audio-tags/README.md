# audio-tags

Normalize core tags across FLAC and common lossy formats. FLAC uses `metaflac`;
others remux with `ffmpeg -c copy`.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Normalize tags across FLAC and common lossy formats.

Usage:
  audio-tags.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -A / --fill-albumartist   Set album artist from artist when missing

FLAC uses metaflac; other formats remux with ffmpeg -c copy.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
