# disc-inventory

Catalog unprocessed disc layouts under roots: `VIDEO_TS`, `BDMV`, and album
dirs with `.cue` sheets. A deduplicated TSV snapshot is written atomically to
the XDG state directory; override it with `--report FILE`.

Part of **[audio-utils](../../../)**.
