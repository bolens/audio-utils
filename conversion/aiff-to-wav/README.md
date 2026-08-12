# aiff-to-wav

AIFF/AIF → WAV PCM remux with MD5 verify + tag copy.

Part of **[audio-utils](../../)**.

## Use and verification

This changes the PCM container from AIFF to WAV without intentionally changing
sample data. The `.wav` sibling is written beside the source.

```bash
./aiff-to-wav.sh -n /path/to/session
./aiff-to-wav.sh /path/to/session
```

The source and output are probed, remuxed through FFmpeg, and decoded for a PCM
MD5 comparison before atomic installation. This is stronger than checking file
size or duration and accommodates expected container-header differences.

Existing WAV siblings are skipped only when decoded audio matches. `-d`
deletes AIFF after verified conversion, while `-D` applies the same strong
check to an existing WAV before cleanup. Use `-n` before deletion. Container
metadata support differs between AIFF and WAV, so preserve specialized chunks
separately. See [format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Remux AIFF -> WAV (PCM) with MD5 verification.

Usage:
  aiff-to-wav.sh DIR [DIR ...]
  find-*-dirs.sh | aiff-to-wav.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
