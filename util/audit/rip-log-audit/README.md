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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
rip-log-audit - validate CD ripper logs (EAC / XLD / Whipper / CUETools).

Usage:
  rip-log-audit.sh DIR [DIR ...]
  find-log-dirs.sh | rip-log-audit.sh

Options:
  --strict   Require AccurateRip/CTDB coverage and an OK summary
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
