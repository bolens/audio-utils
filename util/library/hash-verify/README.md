# hash-verify

Verify or write sidecar `.sha256` / `.md5` checksums beside audio files.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Verify or write sidecar checksums (.sha256 / .md5) for audio files.

Usage:
  hash-verify.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -w / --write   Write sidecars (default: verify existing)
  --sha256       Use SHA-256 (default)
  --md5          Use MD5

-d / -D rejected.
Exit codes: 0 ok, 1 mismatches/missing, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
