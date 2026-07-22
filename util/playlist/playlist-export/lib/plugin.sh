#!/usr/bin/env bash
# playlist-export — copy playlist contents to a device directory.

AU_TOOL_NAME="${AU_TOOL_NAME:-playlist-export}"
AU_SOURCE_EXT=m3u
AU_DEST_EXT=m3u
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=plexp
AU_SUCCESS_COLUMNS='timestamp,playlist,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_PLAYLIST
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

EXPORT_DEST="${EXPORT_DEST:-}"
EXPORT_NUMBER="${EXPORT_NUMBER:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --dest=*)
      EXPORT_DEST="${1#--dest=}"; AU_CONSUMED=1
      export AU_CONSUMED EXPORT_DEST; return 0 ;;
    --dest)
      [[ -n "${2:-}" ]] || { echo "Error: --dest needs DIR" >&2; return 1; }
      EXPORT_DEST=$2; AU_CONSUMED=2
      export AU_CONSUMED EXPORT_DEST; return 0 ;;
    --number)
      EXPORT_NUMBER=1; AU_CONSUMED=1
      export AU_CONSUMED EXPORT_NUMBER; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: playlist-export does not support -d/-D" >&2
    return 1
  fi
  if [[ -z "$EXPORT_DEST" ]]; then
    echo "Error: --dest=DIR is required" >&2
    return 1
  fi
  mkdir -p -- "$EXPORT_DEST" 2>/dev/null || true
  if [[ ! -d "$EXPORT_DEST" || ! -w "$EXPORT_DEST" ]]; then
    echo "Error: destination not a writable directory: $EXPORT_DEST" >&2
    return 1
  fi
  EXPORT_DEST=$(cd -- "$EXPORT_DEST" && pwd)
  export EXPORT_DEST
  return 0
}

plugin_require_deps() {
  require_cmds flock cp
}

plugin_banner_extra() {
  log_always "dest:      ${EXPORT_DEST}"
  if [[ "${EXPORT_NUMBER:-0}" -eq 1 ]]; then
    log_always "mode:      copy + rewrite .m3u (numbered play order)"
  else
    log_always "mode:      copy + rewrite .m3u"
  fi
}

plugin_export_env() {
  export EXPORT_DEST EXPORT_NUMBER AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
