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
