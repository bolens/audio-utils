#!/usr/bin/env bash
# perms-normalize — permission mode report / fix (NAS-friendly 644/755).

AU_TOOL_NAME="${AU_TOOL_NAME:-perms-normalize}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc aac wav aiff aif caf wv ape tak tta cue m3u m3u8 pls xspf jpg jpeg png log"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=permnorm
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

PERMS_APPLY="${PERMS_APPLY:-0}"
PERMS_FILE_MODE="${PERMS_FILE_MODE:-644}"
PERMS_DIR_MODE="${PERMS_DIR_MODE:-755}"

plugin_consume_arg() {
  case "${1:-}" in
    --apply)
      PERMS_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED PERMS_APPLY; return 0 ;;
    --file-mode=*)
      PERMS_FILE_MODE="${1#--file-mode=}"; AU_CONSUMED=1
      export AU_CONSUMED PERMS_FILE_MODE; return 0 ;;
    --file-mode)
      [[ -n "${2:-}" ]] || { echo "Error: --file-mode needs NNN" >&2; return 1; }
      PERMS_FILE_MODE=$2; AU_CONSUMED=2
      export AU_CONSUMED PERMS_FILE_MODE; return 0 ;;
    --dir-mode=*)
      PERMS_DIR_MODE="${1#--dir-mode=}"; AU_CONSUMED=1
      export AU_CONSUMED PERMS_DIR_MODE; return 0 ;;
    --dir-mode)
      [[ -n "${2:-}" ]] || { echo "Error: --dir-mode needs NNN" >&2; return 1; }
      PERMS_DIR_MODE=$2; AU_CONSUMED=2
      export AU_CONSUMED PERMS_DIR_MODE; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: perms-normalize does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: perms-normalize does not support -y (use --apply)" >&2
    return 1
  fi
  local m
  for m in "$PERMS_FILE_MODE" "$PERMS_DIR_MODE"; do
    if ! [[ "$m" =~ ^[0-7]{3,4}$ ]]; then
      echo "Error: mode must be octal (got: $m)" >&2
      return 1
    fi
  done
  return 0
}

plugin_require_deps() {
  require_cmds flock stat chmod
}

plugin_banner_extra() {
  if [[ "${PERMS_APPLY:-0}" -eq 1 ]]; then
    log_always "mode:      apply chmod (files=${PERMS_FILE_MODE} dirs=${PERMS_DIR_MODE})"
  else
    log_always "mode:      report modes (files=${PERMS_FILE_MODE} dirs=${PERMS_DIR_MODE}; use --apply)"
  fi
}

plugin_export_env() {
  if [[ -z "${AU_PERMS_STATE:-}" ]]; then
    AU_PERMS_STATE=$(audio_utils_mktemp_d "permnorm.XXXXXX")
    register_tmpdir "$AU_PERMS_STATE"
  fi
  export AU_PERMS_STATE PERMS_APPLY PERMS_FILE_MODE PERMS_DIR_MODE \
    AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
