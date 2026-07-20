# Adding a converter

1. Copy a sibling tool directory (prefer a similar lossless or lossy peer).
2. Write `lib/plugin.sh`:
   - Set `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`
   - Optional: `AU_SOURCE_EXTS`, `AU_GETOPT_EXTRA`, `AU_CLEANUP_SKIP=1`, `AU_LOSSLESS_CODEC`, `LOSSY_FAMILY`, …
   - Source `../../lib/plugin_init.sh` (loads shared libs; auto-sources local `prepare.sh` / `encode.sh` / `convert.sh` if present)
   - Define `plugin_require_deps` and optional hooks (`plugin_parse_opt`, `plugin_sibling_ok`, …)
3. Implement `convert_one` (or call a shared helper):
   - Lossy: set `LOSSY_*`; `convert_one() { lossy_convert_one "$@"; }`
   - PCM remux: `convert_one() { pcm_remux_convert_one "$@"; }`
   - Into FLAC: `convert_one() { to_flac_convert_one "$@"; }` (optional `plugin_decode_prep`)
   - From FLAC lossless: set `AU_LOSSLESS_CODEC`; `convert_one() { from_flac_lossless_convert_one "$@"; }`
   - FLAC → PCM: `convert_one() { flac_to_pcm_convert_one "$@"; }`
   - Multi-stream: `extract_audio_stream_to_flac` / `audio_stream_count`
   - Otherwise: local `lib/convert.sh`
4. `-D` cleanup uses shared `delete_one_existing`; override with `plugin_sibling_ok` or `AU_CLEANUP_SKIP=1`.
5. Thin CLI: set `AU_USAGE_*`, source plugin + `../lib/driver.sh`, `audio_utils_load_config`, `audio_utils_run "$@"`.
6. Add `find-*-dirs.sh`, `convert-all.sh` (`audio_utils_convert_all`), `Makefile` (`include ../lib/tool.mk`), `.shellcheckrc`.
7. Wire into root `Makefile` `TOOLS` and README / docs.

Shared helpers: [`lib/`](../lib/) — `plugin_init.sh`, `lossless.sh`, `lossy.sh`, `pcm_remux.sh`, `success_log.sh`, `delete.sh`, `convert_all.sh`, `tool.mk`, …
