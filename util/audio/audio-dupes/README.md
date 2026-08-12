# audio-dupes

Content duplicates across FLAC and lossy formats. Default: chromaprint
(`fpcalc`). Optional `-M` uses decode MD5.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Find content duplicates across FLAC and lossy formats.

Usage:
  audio-dupes.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --fingerprint   Chromaprint (default)
  -M / --md5      Decode audio MD5 instead

Read-only: -d / -D / -y rejected.
Exit codes: 0 no dupes, 1 dupes/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
