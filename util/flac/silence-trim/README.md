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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
silence-trim - trim leading/trailing silence from FLAC/PCM (report / --apply).

Usage:
  silence-trim.sh DIR [DIR ...]
  find-flac-dirs.sh | silence-trim.sh

Options:
  --silence-sec SEC   Min silence length to treat as edge (default 1.0)
  --silence-db DB     Noise floor (default -50)
  --pad-sec SEC       Keep this much silence at the cut (default 0.05)
  --min-keep SEC      Abort if keep window would be shorter (default 1.0)
  --lead-only         Trim leading silence only
  --trail-only        Trim trailing silence only
  --apply             Rewrite files in place (default: report candidates)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Report-only by default (exit 1 when candidates exist). -d/-D/-y rejected.
Peer of silence-detect (QC) and silence-split (multi-track).
Exit codes: 0 ok, 1 candidates/failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
