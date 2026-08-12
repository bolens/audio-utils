# aiff-to-flac

Verified AIFF/AIF → FLAC (same remux / dual-encode / e2e MD5 bar as wav-to-flac).

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
make convert-quiet
```

Options: `-d` delete source, `-c` clean source from FLAC decode, `-D` cleanup, `-R` retag.

## Verification and maintenance modes

AIFF/AIF follows the high-assurance PCM pipeline: source probing, independent
FLAC encodes, integrity tests, decoded PCM MD5 comparison, tag transfer, and
atomic installation.

An existing FLAC is accepted only when valid and audio-identical. `-R` refreshes
metadata on that sibling without re-encoding. `-c` replaces AIFF with a clean
decode from verified FLAC; `-d` deletes it; `-D` cleans only against existing
verified siblings. Preview each destructive mode. AIFF-specific application
chunks may not map to FLAC, so retain provenance when they matter. See
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert AIFF/AIF files to FLAC in one or more directories, with verification.

Same verification bar as wav-to-flac (remux, dual encode, e2e MD5, tags).

Usage:
  aiff-to-flac.sh DIR [DIR ...]
  find-aiff-dirs.sh | aiff-to-flac.sh
  convert-all.sh [options...]

Options:
  -f FILE     Read directory list from FILE
  -d          Delete AIFF after successful conversion
  -D          Cleanup only: delete AIFFs that already have a sibling FLAC
  -c          Replace AIFF with a clean decode from the verified FLAC
  -R          Retag only: copy metadata/cover onto existing valid FLACs
  -L FILE     Failure log
  -S FILE     Success log CSV or .jsonl
  -n          Dry run
  -y          Overwrite existing FLACs even if flac -t passes
  -j N        Parallel jobs
  -q          Quiet
  -v          Verbose
  -h          Help
  --version   Print version

Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
