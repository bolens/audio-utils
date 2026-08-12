# caf-to-flac

Apple Core Audio Format (`.caf`) → FLAC with PCM MD5 verify. Uses the same
PCM→FLAC pipeline as wav-to-flac / aiff-to-flac (`-c` clean replace, `-R` retag).

| Flag | Description |
|------|-------------|
| `-c` | Replace CAF with clean decode from FLAC |
| `-R` | Retag only: copy metadata onto existing valid FLACs |

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert Apple CAF -> FLAC with PCM audio-MD5 verification.

Usage:
  caf-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | caf-to-flac.sh

Options:
  -f FILE  -d  -D  -c  -R  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
