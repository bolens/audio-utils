#!/usr/bin/env bash
# multi-disc-layout — normalize Disc N/ folders from DISCNUMBER tags.

AU_TOOL_NAME="${AU_TOOL_NAME:-multi-disc-layout}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=multidisc
AU_SUCCESS_COLUMNS='timestamp,flac,dest,audio_md5,flac_sha256,codec,bytes,samples,notes'
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

MULTIDISC_APPLY="${MULTIDISC_APPLY:-0}"
MULTIDISC_PREFIX="${MULTIDISC_PREFIX:-Disc}"

plugin_consume_arg() {
  case "${1:-}" in
    --apply)
      MULTIDISC_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED MULTIDISC_APPLY; return 0 ;;
    --prefix=*)
      MULTIDISC_PREFIX="${1#--prefix=}"; AU_CONSUMED=1
      export AU_CONSUMED MULTIDISC_PREFIX; return 0 ;;
    --prefix)
      [[ -n "${2:-}" ]] || { echo "Error: --prefix needs a name" >&2; return 1; }
      MULTIDISC_PREFIX=$2; AU_CONSUMED=2
      export AU_CONSUMED MULTIDISC_PREFIX; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: multi-disc-layout does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: multi-disc-layout does not support -y (use --apply)" >&2
    return 1
  fi
  export MULTIDISC_APPLY MULTIDISC_PREFIX
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac flock
}

plugin_banner_extra() {
  if [[ "${MULTIDISC_APPLY:-0}" -eq 1 ]]; then
    log_always "mode:      apply disc-subdir (prefix=${MULTIDISC_PREFIX})"
  else
    log_always "mode:      report disc-subdir (use --apply; prefix=${MULTIDISC_PREFIX})"
  fi
}

plugin_export_env() {
  if [[ -z "${AU_MULTIDISC_STATE:-}" ]]; then
    AU_MULTIDISC_STATE=$(audio_utils_mktemp_d "multidisc.XXXXXX")
    register_tmpdir "$AU_MULTIDISC_STATE"
  fi
  export AU_MULTIDISC_STATE MULTIDISC_APPLY MULTIDISC_PREFIX \
    AU_CLEANUP_SKIP
}
