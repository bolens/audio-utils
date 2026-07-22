#!/usr/bin/env bash
# path-audit — flag file / directory names that break portable filesystems.

AU_TOOL_NAME="${AU_TOOL_NAME:-path-audit}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc spx aac wav aiff aif caf wv ape tak tta cue m3u m3u8 pls xspf jpg jpeg png log"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=pathaudit
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

PATH_AUDIT_MAX_PATH="${PATH_AUDIT_MAX_PATH:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --max-path=*)
      PATH_AUDIT_MAX_PATH="${1#--max-path=}"; AU_CONSUMED=1
      export AU_CONSUMED PATH_AUDIT_MAX_PATH; return 0 ;;
    --max-path)
      [[ -n "${2:-}" ]] || { echo "Error: --max-path needs N" >&2; return 1; }
      PATH_AUDIT_MAX_PATH=$2; AU_CONSUMED=2
      export AU_CONSUMED PATH_AUDIT_MAX_PATH; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: path-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: path-audit is read-only; -y is not supported" >&2
    return 1
  fi
  if ! [[ "$PATH_AUDIT_MAX_PATH" =~ ^[0-9]+$ ]]; then
    echo "Error: --max-path must be a non-negative integer (got: $PATH_AUDIT_MAX_PATH)" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flock
  command -v iconv >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  if [[ "$PATH_AUDIT_MAX_PATH" -gt 0 ]]; then
    log_always "mode:      path audit (chars, length, UTF-8; max-path=${PATH_AUDIT_MAX_PATH})"
  else
    log_always "mode:      path audit (chars, component length, UTF-8)"
  fi
}

plugin_export_env() {
  if [[ -z "${AU_PATHAUDIT_STATE:-}" ]]; then
    AU_PATHAUDIT_STATE=$(audio_utils_mktemp_d "pathaudit.XXXXXX")
    register_tmpdir "$AU_PATHAUDIT_STATE"
  fi
  export AU_PATHAUDIT_STATE PATH_AUDIT_MAX_PATH AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
