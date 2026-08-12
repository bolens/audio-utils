# lossy-audit

Health check for portable lossy files: full error-strict audio decode, core
tags, decodable embedded/folder cover, and bitrate floor (default 128 kbps).

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit lossy/portable library files (tags, cover, bitrate floor).

Usage:
  lossy-audit.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --min-kbps=N   Bitrate floor (default 128)

Read-only: -d / -D / -y rejected.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
