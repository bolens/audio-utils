# cue-audit

Read-only CUE health check: UTF-8, resolvable and fully decodable image,
parseable increasing tracks, and a final index inside the image duration.

Part of **[audio-utils](../../../)**.

## Checks performed

For each sheet, the audit verifies text encoding when `iconv` is available,
resolves every referenced image, parses track indexes in increasing order, and
ensures the final index falls inside the image duration. The referenced audio
is fully decoded with strict error handling, so a readable header alone is not
enough to pass.

```bash
./cue-audit.sh /path/to/cue-library
```

Failures distinguish malformed sheets, missing images, invalid track timing,
and decode errors. A clean result means the set is structurally ready for
[`cue-to-flac`](../../../conversion/cue-to-flac/); it does not validate release
metadata against an external database.

This is strictly read-only and rejects `-d`, `-D`, and `-y`. Fix sheets or
images manually, rerun the audit, and only then split. See
[CUE behavior](../../../docs/cue.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit CUE sheets (image present, tracks parse, UTF-8).

Usage:
  cue-audit.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
