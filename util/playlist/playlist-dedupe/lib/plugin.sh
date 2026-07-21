#!/usr/bin/env bash
# playlist-dedupe — rewrite playlists dropping duplicate songs.

AU_TOOL_NAME="${AU_TOOL_NAME:-playlist-dedupe}"
AU_SOURCE_EXT=m3u
AU_SOURCE_EXTS="m3u m3u8 pls xspf"
AU_DEST_EXT=m3u
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=pldedupe
AU_SUCCESS_COLUMNS='timestamp,playlist,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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

PLAYLIST_DEDUPE_BY="${PLAYLIST_DEDUPE_BY:-path}"

plugin_consume_arg() {
  case "${1:-}" in
    --by)
      [[ -n "${2:-}" ]] || { echo "Error: --by needs path|title" >&2; return 1; }
      PLAYLIST_DEDUPE_BY=$2
      AU_CONSUMED=2
      export AU_CONSUMED PLAYLIST_DEDUPE_BY
      return 0
      ;;
    --by=*)
      PLAYLIST_DEDUPE_BY=${1#--by=}
      AU_CONSUMED=1
      export AU_CONSUMED PLAYLIST_DEDUPE_BY
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: playlist-dedupe does not support -d/-D" >&2
    return 1
  fi
  case "${PLAYLIST_DEDUPE_BY}" in
    path|title) ;;
    *)
      echo "Error: --by must be path or title" >&2
      return 1
      ;;
  esac
  return 0
}

plugin_require_deps() {
  require_cmds flock
}

plugin_accept_source() {
  local f=$1 base
  base=$(basename -- "$f")
  case "${base,,}" in
    *.m3u|*.m3u8|*.pls|*.xspf) return 0 ;;
    *) return 1 ;;
  esac
}

plugin_banner_extra() {
  log_always "mode:      dedupe playlists (by ${PLAYLIST_DEDUPE_BY}; keep first)"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP AU_SOURCE_EXTS PLAYLIST_DEDUPE_BY
}
