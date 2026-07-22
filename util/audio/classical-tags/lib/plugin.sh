#!/usr/bin/env bash
# classical-tags — normalize classical role tags; optional TITLE → WORK/MOVEMENT.

AU_TOOL_NAME="${AU_TOOL_NAME:-classical-tags}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=classicaltags
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_DEFAULT
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

CLASSICAL_APPLY="${CLASSICAL_APPLY:-0}"
CLASSICAL_REQUIRE="${CLASSICAL_REQUIRE:-0}"
CLASSICAL_ONLY="${CLASSICAL_ONLY:-1}"

plugin_consume_arg() {
  case "${1:-}" in
    --apply)
      CLASSICAL_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED CLASSICAL_APPLY; return 0 ;;
    --require-roles)
      CLASSICAL_REQUIRE=1; AU_CONSUMED=1
      export AU_CONSUMED CLASSICAL_REQUIRE; return 0 ;;
    --all-genres)
      CLASSICAL_ONLY=0; AU_CONSUMED=1
      export AU_CONSUMED CLASSICAL_ONLY; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: classical-tags does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: classical-tags does not support -y (use --apply)" >&2
    return 1
  fi
  export CLASSICAL_APPLY CLASSICAL_REQUIRE CLASSICAL_ONLY
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  local mode="report classical tags"
  [[ "${CLASSICAL_APPLY:-0}" -eq 1 ]] && mode="apply classical tag normalize"
  [[ "${CLASSICAL_REQUIRE:-0}" -eq 1 ]] && mode+="; require COMPOSER"
  [[ "${CLASSICAL_ONLY:-1}" -eq 0 ]] && mode+="; all genres"
  log_always "mode:      $mode"
}

plugin_export_env() {
  export CLASSICAL_APPLY CLASSICAL_REQUIRE CLASSICAL_ONLY AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
