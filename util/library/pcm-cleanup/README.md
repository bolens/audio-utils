# pcm-cleanup

Find leftover `.wav` / `.aiff` / `.aif` / `.caf` beside a verified FLAC sibling.
Default reports (fails); `-d` deletes when audio MD5 matches.

Part of **[audio-utils](../../../)**.

## Audit-first workflow

The tool scans WAV, AIFF/AIF, and CAF files and looks for a same-stem `.flac`
sibling. Default mode deliberately exits with a finding for every leftover PCM
file, even when its FLAC is good, making it suitable for a pre-cleanup audit.

```bash
./pcm-cleanup.sh /path/to/library
./pcm-cleanup.sh -n -d /path/to/library
```

## Deletion requirements

`-d` removes a PCM file only when all of these are true:

- the same-stem FLAC exists;
- the FLAC passes integrity validation; and
- decoded PCM MD5 matches the source exactly.

A missing, corrupt, or audio-mismatched sibling is reported and the PCM source
is retained. `-D` is rejected because cleanup is already the explicit `-d`
operation. Run with `-n -d` first and keep an independent backup when cleaning
an archive.

Requires `flac`, `ffmpeg`, and `ffprobe`. This tool is for redundant uncompressed
siblings, not arbitrary WAV/AIFF files with different mastering or sample
layout. See [format verification](../../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Find leftover WAV/AIFF/CAF beside verified FLAC siblings.

Usage:
  pcm-cleanup.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -d              Delete PCM when FLAC sibling verifies (MD5 match)

Default is report-only (exit 1 when leftovers found). -D rejected.
Exit codes: 0 clean, 1 leftovers/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
