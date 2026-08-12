# album-incomplete

Read-only completeness check, one result per directory. Complements
[`album-audit`](../album-audit/) (tag/rate consistency) with:

- Track gaps and missing `TRACKNUMBER`
- File count vs `TOTALTRACKS` / `TRACKTOTAL` (incomplete or extra)
- Distinct `DISCNUMBER` values vs `TOTALDISCS` / `DISCTOTAL`
- Duration outliers vs the album median (`--duration-ratio`, default `0.35`;
  disable with `--no-duration`)

Part of **[audio-utils](../../../)**.

```bash
./album-incomplete.sh -n DIR
./album-incomplete.sh --no-duration DIR
make help
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
album-incomplete - flag incomplete albums (tracks/discs/duration outliers).

Usage:
  album-incomplete.sh DIR [DIR ...]
  find-flac-dirs.sh | album-incomplete.sh

Options:
  --duration-ratio R   Outlier threshold vs median (default 0.35)
  --no-duration        Skip duration outlier checks
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected. One result per directory.
Complements album-audit (consistency) with completeness signals.
Exit codes: 0 complete, 1 incomplete, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
