# Adding a non-conversion util

Library lifecycle tools (verify, ReplayGain, artwork, audit) share the converter CLI stack but do **not** use the convert pipelines (`pcm_to_flac`, `lossy`, `lossless`, …).

First-wave tools: [`flac-verify/`](../flac-verify/) → [`flac-replaygain/`](../flac-replaygain/) → [`flac-artwork/`](../flac-artwork/) → [`flac-audit/`](../flac-audit/).

## When to use this vs a converter

| | Converter | Util |
|---|-----------|------|
| Purpose | Format transform (usually to/from FLAC) | Integrity, tags, art, reports |
| Plugin | Wire a shared pipeline or local `convert.sh` | Local `convert_one` = the operation |
| Sibling / `-D` | Often deletes source after verified sibling | Prefer read-only; set `AU_CLEANUP_SKIP=1` |
| Disk factor | Space for temps / outputs | Often `0` (no write) |

## Scaffold

1. Copy [`flac-verify/`](../flac-verify/) (or a thin FLAC-scanning converter).
2. Write `lib/plugin.sh`:
   - Set `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`
   - For in-place / no-output tools: `AU_DEST_EXT` may equal `AU_SOURCE_EXT` (driver still requires it)
   - Set `AU_CLEANUP_SKIP=1` when `-D` must be a no-op
   - Source `../../lib/plugin_init.sh`
   - Define `plugin_require_deps` and `convert_one` (or put `convert_one` in `lib/convert.sh` — auto-sourced)
   - Reject destructive flags in `plugin_after_flags` when the tool is read-only
3. Thin CLI (same as converters):

   ```bash
   set -euo pipefail
   AU_USAGE_START=2
   AU_USAGE_END=<last-comment-line>
   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/cli.sh"
   audio_utils_cli_run "$@"
   ```

4. Add `find-*-dirs.sh`, `convert-all.sh` (`audio_utils_convert_all`), `Makefile` (`include ../lib/tool.mk`), `.shellcheckrc`.
5. Wire into root `Makefile` `TOOLS`, [README](../README.md), and [requirements.md](requirements.md) if deps differ.

## Required plugin surface

Still the driver contract from [`lib/driver.sh`](../lib/driver.sh):

- `convert_one PATH` — perform the util op (verify, tag, …)
- `delete_one_existing PATH` — default from [`lib/delete.sh`](../lib/delete.sh); skip via `AU_CLEANUP_SKIP=1`
- `init_success_log` — from [`lib/success_log.sh`](../lib/success_log.sh)
- `plugin_require_deps`

Optional: `plugin_parse_opt`, `plugin_after_flags`, `plugin_banner_extra`, `plugin_export_env`, `plugin_accept_source`.

## Make targets

`tool.mk` still exposes `convert` / `convert-quiet` / `dry-run` — for utils these mean “run the batch op over roots,” not “encode.” Prefer that naming over forking Make for each util.

## Docs

Link new tools from the root README table and this doc’s first-wave list when they land.
