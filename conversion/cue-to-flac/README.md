# cue-to-flac

Split CUE + image → per-track FLAC beside the sheet.

Part of **[audio-utils](../../)**.

## Inputs and naming

The CUE sheet resolves its referenced image relative to the sheet, with a
same-stem fallback for common moved sets. Track indexes must be valid and
strictly increasing. Outputs are written beside the CUE as
`NN - sanitized title.flac`; performer, title, and track number are applied
from the sheet.

```bash
./cue-to-flac.sh -n /path/to/album.cue
./cue-to-flac.sh /path/to/album.cue
```

Dry-run output lists each planned filename and time range, which is especially
useful before splitting sheets with unusual indexes or characters.

## Verification and reruns

Every segment is extracted to temporary PCM, dual-encoded and verified through
the shared FLAC pipeline, then tagged with a before/after audio-MD5 check. A
track is installed only after all checks pass. Valid existing FLACs are skipped
unless `-y` requests replacement; failures in one track are reported without
presenting the whole sheet as successful.

## Safety and limitations

The CUE sheet is provenance and is always retained. `-d` and `-D` are rejected;
the referenced image is not automatically deleted either. CUE supports a
limited text model, so review complex multi-file sheets and nonstandard index
layouts. See [CUE behavior](../../docs/cue.md) and
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Split CUE sheet + image into per-track FLAC files.

Usage:
  cue-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | cue-to-flac.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

-d / -D rejected (CUE sheet is kept).
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
