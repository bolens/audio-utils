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

## Duration heuristic

For albums with at least three measured tracks, durations are sorted and
compared with the median. With the default ratio `0.35`, tracks shorter than
35% of the median or longer than roughly 2.86 times it are flagged. This can
identify truncated files and accidental inserts, but intros, bonus tracks, and
long-form pieces can be legitimate outliers.

Use `--no-duration` when structure alone is authoritative, or tune the ratio
for the collection before treating findings as defects. Track/disc totals are
also policy signals: hidden tracks and intentionally omitted discs need manual
interpretation.

The audit coordinates one result per directory, is read-only, and rejects
mutation flags. Correct tags or restore missing media, then rerun alongside
`album-audit` for consistency checks.

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
