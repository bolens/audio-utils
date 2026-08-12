# dvd-to-flac

Extract audio from DVD `VIDEO_TS` (VOBs) → FLAC beside the disc.
Requires **libdvdcss**. Uses existing VOBs on disk (not a device ripper).
`-j` is accepted for CLI parity but extract is serial.

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Extract audio from DVD VIDEO_TS directories to FLAC.

Usage:
  dvd-to-flac.sh /path/to/VIDEO_TS [/path/to/disc ...]
  find-video_ts-dirs.sh | dvd-to-flac.sh
  dvd-to-flac.sh -f list.txt

Options:
  -f FILE  -L FILE  -S FILE  --dirs0  -n  -y  -q  -v  -h  --version
  -j N     Accepted for CLI parity; DVD extract is serial (ignored)

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
