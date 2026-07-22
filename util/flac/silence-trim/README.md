# silence-trim

Trim leading/trailing silence from FLAC/WAV/AIFF/CAF. Report-only by default
(exit 1 per candidate); `--apply` rewrites in place. FLAC tags + cover are
restored via `tag_flac_from_source`.

Defaults match [`silence-detect`](../../audit/silence-detect/): silence ≥ 1.0 s
at −50 dB. Keeps `--pad-sec` (default 0.05 s) at each cut; refuses a trim that
would leave less than `--min-keep` (default 1.0 s).

| Flag | Meaning |
|------|---------|
| `--silence-sec` / `--silence-db` | Detection threshold |
| `--pad-sec` | Retain a little edge silence |
| `--min-keep` | Minimum remaining duration |
| `--lead-only` / `--trail-only` | One edge only |
| `--apply` | Write (default: report candidates) |

Peer of [`silence-detect`](../../audit/silence-detect/) (QC) and
[`silence-split`](../silence-split/) (split on mid-file silence).

Part of **[audio-utils](../../../)**.

```bash
./silence-trim.sh -n DIR
./silence-trim.sh --apply DIR
make help
```
