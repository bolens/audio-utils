# rip-log-audit

Read-only audit of CD ripper `.log` sidecars (Exact Audio Copy, XLD,
Whipper/morituri, CUETools/CUERipper).

Checks Secure (or equivalent) mode, CRC / rip errors, and AccurateRip or CTDB
health. Unknown ripper banners fail as `unknown-ripper`. Non-UTF-8 logs are
flagged but still parsed.

Use `--strict` to also require AccurateRip/CTDB coverage and an OK summary
line — useful when you treat “no AR data” as a failure.

Pairs with [`cue-audit`](../cue-audit/) and [`cdda-to-flac`](../../../conversion/cdda-to-flac/).

Part of **[audio-utils](../../../)**.

```bash
./rip-log-audit.sh -n DIR
./rip-log-audit.sh --strict DIR
make help
```
