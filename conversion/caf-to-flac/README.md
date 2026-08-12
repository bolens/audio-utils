# caf-to-flac

Apple Core Audio Format (`.caf`) → FLAC with PCM MD5 verify. Uses the same
PCM→FLAC pipeline as wav-to-flac / aiff-to-flac (`-c` clean replace, `-R` retag).

| Flag | Description |
|------|-------------|
| `-c` | Replace CAF with clean decode from FLAC |
| `-R` | Retag only: copy metadata onto existing valid FLACs |

Part of **[audio-utils](../../)**.

## Verification and maintenance modes

CAF PCM enters the same high-assurance path as WAV and AIFF: probing, independent
temporary encodes, FLAC integrity tests, end-to-end PCM MD5 comparison, and
atomic installation.

Existing FLAC siblings are trusted only after integrity and audio checks. `-R`
refreshes supported metadata; `-c` replaces CAF with a clean FLAC decode; `-d`
deletes it; and `-D` cleans only where a matching sibling exists. Preview all
destructive modes with `-n`. Unsupported CAF codec variants fail rather than
bypassing verification, and custom CAF metadata may not map to Vorbis comments.

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
