# Adding a non-conversion util

Library lifecycle tools live under [`util/`](../util/), grouped by category:
`util/<category>/<tool>/` (`flac/`, `audio/`, `playlist/`, `audit/`,
`library/`). They share the converter CLI stack but do **not** use the convert
pipelines (`pcm_to_flac`, `lossy`, `lossless`, …).

**Tool inventory** lives in the root [README](../README.md) util table — do not duplicate lists here. Topic notes: [playlists.md](playlists.md), [cue.md](cue.md), [discs.md](discs.md), [formats.md](formats.md). Deps: [requirements.md](requirements.md). Converters: [adding-a-converter.md](adding-a-converter.md).

## When to use this vs a converter

| | Converter (`conversion/`) | Util (`util/`) |
|---|-----------|------|
| Purpose | Format transform (usually to/from FLAC) | Integrity, tags, art, reports |
| Plugin | Wire a shared pipeline or local `convert.sh` | Local `convert_one` = the operation |
| Sibling / `-D` | Often deletes source after verified sibling | Prefer read-only; set `AU_CLEANUP_SKIP=1` |
| Disk factor | Space for temps / outputs | Often `0` (no write) |

## Scaffold

Fastest path: `make new-util CATEGORY=<category> NAME=<tool>` (wraps
[`scripts/new-tool.sh`](../scripts/new-tool.sh)) generates the full skeleton.
The manual steps below describe what the generator produces.

1. Copy a peer under the right category (e.g. [`util/flac/flac-verify/`](../util/flac/flac-verify/) or a thin multi-ext tool like [`util/audit/cue-audit/`](../util/audit/cue-audit/)).
2. Write `lib/plugin.sh`:
   - Set `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`
   - For in-place / no-output tools: `AU_DEST_EXT` may equal `AU_SOURCE_EXT` (driver still requires it)
   - Set `AU_CLEANUP_SKIP=1` when `-D` must be a no-op
   - Locate the repo root with the walk-up idiom and source `lib/plugin_init.sh` (see any peer plugin — tools work at any nesting depth)
   - Define `plugin_require_deps` and `convert_one` (or put `convert_one` in `lib/convert.sh` — auto-sourced)
   - Reject destructive flags in `plugin_after_flags` when the tool is read-only
3. Thin CLI (same as converters):

   ```bash
   set -euo pipefail
   AU_USAGE_START=2
   AU_USAGE_END=<last-comment-line>
   AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
   while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
     [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
     AU_ROOT=$(dirname "$AU_ROOT")
   done
   source "$AU_ROOT/lib/cli/cli.sh"
   audio_utils_cli_run "$@"
   ```

4. Add `find-*-dirs.sh`, `convert-all.sh` (`audio_utils_convert_all`), `Makefile` (walk-up `AU_ROOT` + `include $(AU_ROOT)/lib/tool.mk`), `.shellcheckrc` (copy a peer's).
5. The root `Makefile` and CI auto-discover any `util/*/*/Makefile` — no wiring needed there. Add the tool to the root [README](../README.md) util table (right category section), and to [requirements.md](requirements.md) if deps differ. Add or update a topic doc under [`docs/`](README.md) when behavior needs more than a README row.
6. Add a functional test under [`tests/`](../tests/) when the tool has verifiable behavior (see `tests/README.md`).

## Required plugin surface

Still the driver contract from [`lib/cli/driver.sh`](../lib/cli/driver.sh):

- `convert_one PATH` — perform the util op (verify, tag, …)
- `delete_one_existing PATH` — default from [`lib/core/delete.sh`](../lib/core/delete.sh); skip via `AU_CLEANUP_SKIP=1`
- `init_success_log` — from [`lib/core/success_log.sh`](../lib/core/success_log.sh)
- `plugin_require_deps`

Optional: `plugin_parse_opt`, `plugin_after_flags`, `plugin_banner_extra`, `plugin_export_env`, `plugin_accept_source`, `plugin_finalize`.

## Make targets

`tool.mk` still exposes `convert` / `convert-quiet` / `dry-run` — for utils these mean “run the batch op over roots,” not “encode.” Prefer that naming over forking Make for each util.

## See also

[docs index](README.md) · [adding-a-converter.md](adding-a-converter.md) · [requirements.md](requirements.md) · [root README](../README.md)
