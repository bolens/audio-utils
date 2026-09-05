# flac-to-aiff

Verified FLAC → AIFF (bit-depth-matched big-endian PCM, dual-decode MD5, tags).

```bash
make convert-quiet
```

## Output and verification

AIFF is uncompressed PCM, so outputs are much larger than FLAC. The converter
selects bit-depth-matched big-endian PCM and compares independently decoded PCM
MD5 before atomically installing the `.aiff` sibling.

Existing AIFF files are skipped only when they probe correctly and contain the
same samples. `-d` and cleanup-only `-D` use that strong check; normally retain
FLAC as the archive master. Tags are copied where AIFF supports them, but custom
Vorbis comments and pictures may not map perfectly. See
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC files to AIFF, with dual-decode MD5 verification.

Usage:
  flac-to-aiff.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-aiff.sh
  convert-all.sh [options...]

Options:
  -f FILE     Read directory list from FILE
  -d          Delete FLAC after successful conversion
  -D          Cleanup only: delete FLACs that already have a valid sibling AIFF
  -L FILE     Failure log
  -S FILE     Success log CSV or .jsonl
  -n          Dry run
  -y          Overwrite existing AIFFs even if probe/MD5 pass
  -j N        Parallel jobs
  -q          Quiet
  -v          Verbose
  -h          Help
  --version   Print version

Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
