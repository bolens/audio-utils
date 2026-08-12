# pcm-cleanup

Find leftover `.wav` / `.aiff` / `.aif` / `.caf` beside a verified FLAC sibling.
Default reports (fails); `-d` deletes when audio MD5 matches.

Part of **[audio-utils](../../../)**.

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
