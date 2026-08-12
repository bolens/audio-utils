# streams-to-flac

Extract each audio stream in a container → `basename.aN.flac`.

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Extract all audio streams from media containers to FLAC.

Usage:
  streams-to-flac.sh DIR [DIR ...]
  find-media-dirs.sh | streams-to-flac.sh

Options:
  -f FILE  -d  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  (-D cleanup is unsupported; use -d to delete the container after extract)

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
