#!/usr/bin/env bash
# flac-rename plugin — rename / layout FLACs from tags.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-rename}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacrename
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

# inplace | artist-album
RENAME_LAYOUT="${RENAME_LAYOUT:-inplace}"
RENAME_DEST_ROOT="${RENAME_DEST_ROOT:-}"

plugin_consume_arg() {
  case "${1:-}" in
    --layout=*)
      RENAME_LAYOUT="${1#--layout=}"
      AU_CONSUMED=1
      export AU_CONSUMED RENAME_LAYOUT
      return 0
      ;;
    --layout)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --layout requires inplace|artist-album" >&2
        return 1
      fi
      RENAME_LAYOUT=$2
      AU_CONSUMED=2
      export AU_CONSUMED RENAME_LAYOUT
      return 0
      ;;
    --dest-root=*)
      RENAME_DEST_ROOT="${1#--dest-root=}"
      AU_CONSUMED=1
      export AU_CONSUMED RENAME_DEST_ROOT
      return 0
      ;;
    --dest-root)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --dest-root requires a directory" >&2
        return 1
      fi
      RENAME_DEST_ROOT=$2
      AU_CONSUMED=2
      export AU_CONSUMED RENAME_DEST_ROOT
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-rename does not support -d/-D" >&2
    return 1
  fi
  case "${RENAME_LAYOUT}" in
    inplace | artist-album) ;;
    *)
      echo "Error: invalid --layout '${RENAME_LAYOUT}' (inplace|artist-album)" >&2
      return 1
      ;;
  esac
  if [[ "${RENAME_LAYOUT}" == artist-album ]]; then
    if [[ -z "${RENAME_DEST_ROOT}" ]]; then
      # Prefer first AUDIO_UTILS_ROOTS entry
      local -a roots=()
      if audio_utils_roots_from_env roots && ((${#roots[@]} > 0)); then
        RENAME_DEST_ROOT=${roots[0]}
      else
        echo "Error: --layout=artist-album needs --dest-root or AUDIO_UTILS_ROOTS" >&2
        return 1
      fi
    fi
    if [[ ! -d "${RENAME_DEST_ROOT}" ]]; then
      if ! mkdir -p -- "${RENAME_DEST_ROOT}"; then
        echo "Error: cannot create --dest-root: ${RENAME_DEST_ROOT}" >&2
        return 1
      fi
    fi
    RENAME_DEST_ROOT=$(cd -- "${RENAME_DEST_ROOT}" && pwd)
  fi
  export RENAME_LAYOUT RENAME_DEST_ROOT
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac flock
}

plugin_banner_extra() {
  log_always "layout:    ${RENAME_LAYOUT}"
  if [[ "${RENAME_LAYOUT}" == artist-album ]]; then
    log_always "dest-root: ${RENAME_DEST_ROOT}"
  fi
}

plugin_export_env() {
  export RENAME_LAYOUT RENAME_DEST_ROOT AU_CLEANUP_SKIP
}
