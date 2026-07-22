#!/usr/bin/env bash
# library-prune — orphaned portable files without a FLAC master.

AU_TOOL_NAME="${AU_TOOL_NAME:-library-prune}"
AU_SOURCE_EXT=mp3
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=libprune
AU_SUCCESS_COLUMNS='timestamp,portable,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_LOSSY
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

PRUNE_FLAC_ROOT="${PRUNE_FLAC_ROOT:-}"
PRUNE_PORTABLE_ROOT="${PRUNE_PORTABLE_ROOT:-}"
PRUNE_MASTER_EXTS="${PRUNE_MASTER_EXTS:-flac}"
PRUNE_DELETE="${PRUNE_DELETE:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --flac-root=*)
      PRUNE_FLAC_ROOT="${1#--flac-root=}"; AU_CONSUMED=1
      export AU_CONSUMED PRUNE_FLAC_ROOT; return 0 ;;
    --flac-root)
      [[ -n "${2:-}" ]] || { echo "Error: --flac-root needs DIR" >&2; return 1; }
      PRUNE_FLAC_ROOT=$2; AU_CONSUMED=2
      export AU_CONSUMED PRUNE_FLAC_ROOT; return 0 ;;
    --portable-root=*)
      PRUNE_PORTABLE_ROOT="${1#--portable-root=}"; AU_CONSUMED=1
      export AU_CONSUMED PRUNE_PORTABLE_ROOT; return 0 ;;
    --portable-root)
      [[ -n "${2:-}" ]] || { echo "Error: --portable-root needs DIR" >&2; return 1; }
      PRUNE_PORTABLE_ROOT=$2; AU_CONSUMED=2
      export AU_CONSUMED PRUNE_PORTABLE_ROOT; return 0 ;;
    --exts=*)
      PRUNE_MASTER_EXTS="${1#--exts=}"; PRUNE_MASTER_EXTS=${PRUNE_MASTER_EXTS//,/ }
      AU_CONSUMED=1; export AU_CONSUMED PRUNE_MASTER_EXTS; return 0 ;;
    --exts)
      [[ -n "${2:-}" ]] || { echo "Error: --exts needs list" >&2; return 1; }
      PRUNE_MASTER_EXTS=${2//,/ }; AU_CONSUMED=2
      export AU_CONSUMED PRUNE_MASTER_EXTS; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: library-prune does not support -D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: library-prune does not support -y" >&2
    return 1
  fi
  # Map shared -d to "delete orphans"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    PRUNE_DELETE=1
    DELETE_SOURCE=0
  fi
  if [[ -z "$PRUNE_FLAC_ROOT" ]]; then
    echo "Error: --flac-root=DIR is required" >&2
    return 1
  fi
  if [[ ! -d "$PRUNE_FLAC_ROOT" ]]; then
    echo "Error: FLAC root not a directory: $PRUNE_FLAC_ROOT" >&2
    return 1
  fi
  PRUNE_FLAC_ROOT=$(cd -- "$PRUNE_FLAC_ROOT" && pwd)
  if [[ -n "$PRUNE_PORTABLE_ROOT" ]]; then
    if [[ ! -d "$PRUNE_PORTABLE_ROOT" ]]; then
      echo "Error: portable root not a directory: $PRUNE_PORTABLE_ROOT" >&2
      return 1
    fi
    PRUNE_PORTABLE_ROOT=$(cd -- "$PRUNE_PORTABLE_ROOT" && pwd)
  fi
  export PRUNE_FLAC_ROOT PRUNE_PORTABLE_ROOT PRUNE_MASTER_EXTS PRUNE_DELETE
  return 0
}

plugin_require_deps() {
  require_cmds flock
}

plugin_banner_extra() {
  log_always "flac root: ${PRUNE_FLAC_ROOT}"
  log_always "masters:   ${PRUNE_MASTER_EXTS}"
  if [[ "${PRUNE_DELETE:-0}" -eq 1 ]]; then
    log_always "mode:      delete orphaned portable files"
  else
    log_always "mode:      report orphans (use -d to delete)"
  fi
}

plugin_export_env() {
  export PRUNE_FLAC_ROOT PRUNE_PORTABLE_ROOT PRUNE_MASTER_EXTS PRUNE_DELETE \
    AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
