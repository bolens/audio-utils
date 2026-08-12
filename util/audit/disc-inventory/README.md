# disc-inventory

Catalog unprocessed disc layouts under roots: `VIDEO_TS`, `BDMV`, and album
dirs with `.cue` sheets. A deduplicated TSV snapshot is written atomically to
the XDG state directory; override it with `--report FILE`.

Part of **[audio-utils](../../../)**.

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
