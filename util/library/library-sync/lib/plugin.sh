#!/usr/bin/env bash
# library-sync — check portable siblings exist for each FLAC.

AU_TOOL_NAME="${AU_TOOL_NAME:-library-sync}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=libsync
AU_SUCCESS_COLUMNS='timestamp,flac,status,audio_md5,flac_sha256,codec,bytes,samples,notes'
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
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

SYNC_PORTABLE_ROOT="${SYNC_PORTABLE_ROOT:-}"
# Default: full lossy portable cluster (override with --exts).
SYNC_EXTS="${SYNC_EXTS:-$AU_AUDIO_EXTS_LOSSY}"

plugin_consume_arg() {
  case "${1:-}" in
    --portable-root=*)
      SYNC_PORTABLE_ROOT="${1#--portable-root=}"; AU_CONSUMED=1
      export AU_CONSUMED SYNC_PORTABLE_ROOT; return 0 ;;
    --portable-root)
      [[ -n "${2:-}" ]] || { echo "Error: --portable-root needs DIR" >&2; return 1; }
      SYNC_PORTABLE_ROOT=$2; AU_CONSUMED=2
      export AU_CONSUMED SYNC_PORTABLE_ROOT; return 0 ;;
    --exts=*)
      SYNC_EXTS="${1#--exts=}"; SYNC_EXTS=${SYNC_EXTS//,/ }
      AU_CONSUMED=1; export AU_CONSUMED SYNC_EXTS; return 0 ;;
    --exts)
      [[ -n "${2:-}" ]] || { echo "Error: --exts needs list" >&2; return 1; }
      SYNC_EXTS=${2//,/ }; AU_CONSUMED=2
      export AU_CONSUMED SYNC_EXTS; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: library-sync is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: library-sync is read-only; -y is not supported" >&2
    return 1
  fi
  if [[ -z "${SYNC_PORTABLE_ROOT}" ]]; then
    echo "Error: --portable-root=DIR is required" >&2
    return 1
  fi
  if [[ ! -d "${SYNC_PORTABLE_ROOT}" ]]; then
    echo "Error: portable root not a directory: ${SYNC_PORTABLE_ROOT}" >&2
    return 1
  fi
  SYNC_PORTABLE_ROOT=$(cd -- "$SYNC_PORTABLE_ROOT" && pwd)
  # FLAC root: first of AUDIO_UTILS_ROOTS or first scanned dir — set in export
  export SYNC_PORTABLE_ROOT SYNC_EXTS
  return 0
}

plugin_require_deps() {
  require_cmds flac flock
}

plugin_banner_extra() {
  log_always "portable:  ${SYNC_PORTABLE_ROOT}"
  log_always "exts:      ${SYNC_EXTS}"
}

plugin_export_env() {
  if [[ -z "${SYNC_FLAC_ROOT:-}" ]]; then
    local -a roots=()
    if audio_utils_roots_from_env roots && ((${#roots[@]} > 0)); then
      SYNC_FLAC_ROOT=$(cd -- "${roots[0]}" && pwd)
    fi
  fi
  export SYNC_PORTABLE_ROOT SYNC_EXTS SYNC_FLAC_ROOT AU_CLEANUP_SKIP
}
