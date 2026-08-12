# disc-inventory

Catalog unprocessed disc layouts under roots: `VIDEO_TS`, `BDMV`, and album
dirs with `.cue` sheets. A deduplicated TSV snapshot is written atomically to
the XDG state directory; override it with `--report FILE`.

Part of **[audio-utils](../../../)**.

## Inventory units

Discovery treats authored DVD `VIDEO_TS` trees, Blu-ray `BDMV` trees, and
directories containing CUE sheets as disc units. Results are deduplicated and
written as `kind<TAB>path` beneath a header.

```bash
./disc-inventory.sh /path/to/incoming
./disc-inventory.sh --report /tmp/discs.tsv /path/to/incoming
```

Workers collect findings into session state; final publication sorts and
deduplicates them, writes a temporary report beside the destination, and moves
it atomically. A failed publication does not replace the prior snapshot.

This is an inventory, not a media-integrity audit: it does not decrypt discs,
decode every title, or prove CUE timing. Follow findings with `dvd-to-flac`,
`bluray-to-flac`, or `cue-audit` as appropriate. The tool is read-only and
rejects `-d`, `-D`, and `-y`. See [disc workflows](../../../docs/discs.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Inventory VIDEO_TS / BDMV / CUE units under library roots.

Usage:
  disc-inventory.sh DIR [DIR ...]
  find-disc-units.sh | disc-inventory.sh

Options:
  --report FILE  Write the durable TSV inventory to FILE
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
