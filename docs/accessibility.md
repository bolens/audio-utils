# CLI accessibility

audio-utils is a text-first bash CLI (no TUI). These conventions keep output usable with screen readers, monochrome terminals, and log grepping.

## Guarantees

- **No ANSI colors** — status is never color-only. `NO_COLOR` / `FORCE_COLOR` are unused today because nothing emits escapes.
- **Word-based status** — `FAIL`, `Error:`, `warning:`, `skip`, `would`, `Done. ok=/failed=`.
- **Line-oriented progress** — no spinners, cursor hide/show, or `\r` rewriting. Progress prefixes look like `[3/10 elapsed=0:01:02 eta=0:00:14]`.
- **Structured failures** — `log_fail` prints labeled `reason` / `detail` / `probe` / `time` lines (still shown under `-q`).
- **ASCII in live messages** — arrows and operators in runtime logs use `->`, `x`, `<=`, `<->` rather than Unicode glyphs.

## Operator tips

| Goal | Flag / habit |
|------|----------------|
| Follow live progress with AT | `-j 1` (serial stderr) |
| Batch review offline | `-L` failure log, `-S` success log |
| Less chatter | `-q` (keeps progress + FAIL + Done) |
| More detail | `-v` |
| Full help | `-h` / `--help` (stdout only) |

Under `-j N` (N>1), workers flock stderr so multi-line `FAIL` blocks and progress lines do not interleave mid-message. Ordering across jobs is still concurrent.

## Exit codes

See the root [README](../README.md#exit-codes): `0` success, `1` run failures, `2` usage/deps.
