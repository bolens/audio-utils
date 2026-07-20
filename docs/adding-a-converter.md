# Adding a converter

1. Copy a sibling tool directory.
2. Write `lib/plugin.sh`:
   - Set `AU_TOOL_NAME`, `AU_SOURCE_EXT`, `AU_DEST_EXT`, `AU_DISK_FACTOR`, `AU_WORKDIR_PREFIX`, `AU_SUCCESS_COLUMNS`
   - Optional: `AU_SOURCE_EXTS` (space-separated), `AU_GETOPT_EXTRA`
   - Source `../../lib/load.sh` and local modules
   - Define `plugin_require_deps`
   - Optional hooks: `plugin_parse_opt`, `plugin_consume_arg`, `plugin_after_flags`, `plugin_banner_extra`, `plugin_export_env`, `plugin_accept_source`
3. Implement `convert_one`, `delete_one_existing`, `init_success_log`.
4. Thin CLI: set `AU_USAGE_*`, source plugin + `../lib/driver.sh`, `audio_utils_load_config`, `audio_utils_run "$@"`.
5. Add `find-*-dirs.sh`, `convert-all.sh`, `Makefile`, `.shellcheckrc`.
6. Wire the tool into the root `Makefile` `TOOLS` list and README / docs.

Shared helpers live under [`lib/`](../lib/) (`driver.sh`, `worker.sh`, `pcm_flac.sh`, `cue.sh`, `lossy.sh`, …).
