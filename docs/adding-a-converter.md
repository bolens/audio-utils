# Adding a converter

1. Copy a sibling tool directory (prefer a similar lossless or lossy peer).
2. Write `lib/plugin.sh`:
   - Set `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`
   - Optional: `AU_SOURCE_EXTS` (space-separated), `AU_GETOPT_EXTRA`, `AU_CLEANUP_SKIP=1`
   - Source `../../lib/load.sh` (pulls in success log, delete, lossy, pcm remux, …)
   - Define `plugin_require_deps`
   - Optional hooks: `plugin_parse_opt`, `plugin_consume_arg`, `plugin_after_flags`, `plugin_banner_extra`, `plugin_export_env`, `plugin_accept_source`, `plugin_sibling_ok`
3. Implement `convert_one` (or call a shared helper):
   - Lossy: set `LOSSY_FAMILY` / `LOSSY_FFMPEG_ENCODER` / quality env vars; `convert_one() { lossy_convert_one "$@"; }`
   - PCM remux: `convert_one() { pcm_remux_convert_one "$@"; }`
   - Otherwise: local `lib/convert.sh`
4. `-D` cleanup uses shared `delete_one_existing`; override with `plugin_sibling_ok SRC DEST` or set `AU_CLEANUP_SKIP=1`.
5. Thin CLI: set `AU_USAGE_*`, source plugin + `../lib/driver.sh`, `audio_utils_load_config`, `audio_utils_run "$@"`.
6. Add `find-*-dirs.sh` (wrap `../lib/find-audio-dirs.sh` or `find_named_dirs`), `convert-all.sh` (`audio_utils_convert_all`), `Makefile` (`include ../lib/tool.mk`), `.shellcheckrc`.
7. Wire the tool into the root `Makefile` `TOOLS` list and README / docs.

Shared helpers live under [`lib/`](../lib/) (`driver.sh`, `worker.sh`, `success_log.sh`, `delete.sh`, `convert_all.sh`, `pcm_flac.sh`, `pcm_remux.sh`, `lossy.sh`, `cue.sh`, `tool.mk`, …).
