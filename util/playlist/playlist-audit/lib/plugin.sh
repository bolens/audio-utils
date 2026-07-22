#!/usr/bin/env bash
# playlist-audit — validate playlist files (paths, empties, dupes, utf-8).

AU_TOOL_NAME="${AU_TOOL_NAME:-playlist-audit}"
AU_SOURCE_EXT=m3u
AU_DEST_EXT=m3u
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=plaudit
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

PLAYLIST_DEDUPE_BY="${PLAYLIST_DEDUPE_BY:-path}"

plugin_consume_arg() {
  case "${1:-}" in
    --by)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --by needs path|title" >&2
        return 1
      fi
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
    echo "Error: playlist-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: playlist-audit is read-only; -y is not supported" >&2
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
  command -v iconv >/dev/null 2>&1 || true
}

# AU_SOURCE_EXTS gates discovery; no redundant accept case.

plugin_banner_extra() {
  log_always "mode:      playlist audit (paths, dupes by ${PLAYLIST_DEDUPE_BY})"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP AU_SOURCE_EXTS PLAYLIST_DEDUPE_BY
}
