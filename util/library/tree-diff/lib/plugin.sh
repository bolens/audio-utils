#!/usr/bin/env bash
# tree-diff — compare files under scanned dirs against --against root.

AU_TOOL_NAME="${AU_TOOL_NAME:-tree-diff}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=treediff
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
AU_SOURCE_EXTS="$AU_AUDIO_EXTS_DEFAULT $AU_AUDIO_EXTS_PCM"
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

DIFF_AGAINST="${DIFF_AGAINST:-}"
DIFF_HASH="${DIFF_HASH:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --against=*)
      DIFF_AGAINST="${1#--against=}"; AU_CONSUMED=1
      export AU_CONSUMED DIFF_AGAINST; return 0 ;;
    --against)
      [[ -n "${2:-}" ]] || { echo "Error: --against needs DIR" >&2; return 1; }
      DIFF_AGAINST=$2; AU_CONSUMED=2
      export AU_CONSUMED DIFF_AGAINST; return 0 ;;
    --hash)
      DIFF_HASH=1; AU_CONSUMED=1
      export AU_CONSUMED DIFF_HASH; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: tree-diff is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: tree-diff is read-only; -y is not supported" >&2
    return 1
  fi
  if [[ -z "${DIFF_AGAINST}" ]]; then
    echo "Error: --against=DIR is required (comparison tree)" >&2
    return 1
  fi
  if [[ ! -d "${DIFF_AGAINST}" ]]; then
    echo "Error: --against is not a directory: ${DIFF_AGAINST}" >&2
    return 1
  fi
  DIFF_AGAINST=$(cd -- "$DIFF_AGAINST" && pwd)
  export DIFF_AGAINST DIFF_HASH
  return 0
}

plugin_require_deps() {
  require_cmds flock
  if [[ "${DIFF_HASH:-0}" -eq 1 ]]; then
    require_cmds sha256sum
  fi
}

plugin_banner_extra() {
  log_always "against:   ${DIFF_AGAINST}"
  if [[ "${DIFF_HASH:-0}" -eq 1 ]]; then
    log_always "compare:   sha256"
  fi
}

plugin_export_env() {
  export DIFF_AGAINST DIFF_HASH AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
