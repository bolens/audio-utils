#!/usr/bin/env bash
# genre-canonicalize — map freeform GENRE tags to a controlled vocabulary.

AU_TOOL_NAME="${AU_TOOL_NAME:-genre-canonicalize}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc spx aac"
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=genrecanon
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

GENRE_APPLY="${GENRE_APPLY:-0}"
GENRE_MAP_FILE="${GENRE_MAP_FILE:-}"

plugin_consume_arg() {
  case "${1:-}" in
    --apply)
      GENRE_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED GENRE_APPLY; return 0 ;;
    --map-file=*)
      GENRE_MAP_FILE="${1#--map-file=}"; AU_CONSUMED=1
      export AU_CONSUMED GENRE_MAP_FILE; return 0 ;;
    --map-file)
      [[ -n "${2:-}" ]] || { echo "Error: --map-file needs a path" >&2; return 1; }
      GENRE_MAP_FILE=$2; AU_CONSUMED=2
      export AU_CONSUMED GENRE_MAP_FILE; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: genre-canonicalize does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: genre-canonicalize does not support -y (use --apply)" >&2
    return 1
  fi
  if [[ -n "${GENRE_MAP_FILE}" && ! -f "${GENRE_MAP_FILE}" ]]; then
    echo "Error: --map-file not found: ${GENRE_MAP_FILE}" >&2
    return 1
  fi
  export GENRE_APPLY GENRE_MAP_FILE
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  # metaflac optional but preferred for FLAC
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  if [[ "${GENRE_APPLY:-0}" -eq 1 ]]; then
    log_always "mode:      apply genre canonicalization"
  else
    log_always "mode:      report genre drift (use --apply)"
  fi
  if [[ -n "${GENRE_MAP_FILE}" ]]; then
    log_always "map-file:  ${GENRE_MAP_FILE}"
  else
    log_always "map-file:  (built-in)"
  fi
}

plugin_export_env() {
  export GENRE_APPLY GENRE_MAP_FILE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
