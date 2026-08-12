# dynamics-report

Read-only EBU R128 survey (ffmpeg `ebur128`): integrated loudness, loudness
range, true peak per file, plus a summary report listing low-LRA
(brickwall-suspect) files and true-peak overs.
The report is installed atomically. Use `--report FILE` to override its XDG
state location.

Scopes the portable+PCM cluster (`--preset portable-pcm`); lossless archives
(wv/ape/tak/tta) are out of scope unless you pass dirs by hand.

Complements [`util/flac-replaygain`](../../flac/flac-replaygain/) /
[`util/audio-replaygain`](../../audio/audio-replaygain/) (which *write* gain tags) —
this tool only measures and reports.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Loudness / dynamics report: integrated LUFS, LRA, true peak (EBU R128).

Usage:
  dynamics-report.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --min-lra=N     Flag files with LRA below N LU in the report (default: 3)
  --report FILE   Write the report to FILE instead of XDG state

Read-only: -d / -D / -y rejected. Summary report written to the state dir.
Exit codes: 0 ok, 1 unreadable files, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
