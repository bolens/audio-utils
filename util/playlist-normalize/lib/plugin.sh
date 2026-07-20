#!/usr/bin/env bash
# playlist-normalize — rewrite playlist format and/or path style.

AU_TOOL_NAME="${AU_TOOL_NAME:-playlist-normalize}"
AU_SOURCE_EXT=m3u
AU_SOURCE_EXTS="m3u m3u8 pls xspf"
AU_DEST_EXT=m3u
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=plnorm
AU_SUCCESS_COLUMNS='timestamp,playlist,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

PLAYLIST_OUT_FORMAT="${PLAYLIST_OUT_FORMAT:-}"
PLAYLIST_PATH_MODE="${PLAYLIST_PATH_MODE:-relative}"
PLAYLIST_DO_DEDUPE="${PLAYLIST_DO_DEDUPE:-0}"
PLAYLIST_DEDUPE_BY="${PLAYLIST_DEDUPE_BY:-path}"

plugin_consume_arg() {
  case "${1:-}" in
    --format)
      [[ -n "${2:-}" ]] || { echo "Error: --format needs m3u|pls|xspf" >&2; return 1; }
      PLAYLIST_OUT_FORMAT=$2
      AU_CONSUMED=2
      export AU_CONSUMED PLAYLIST_OUT_FORMAT
      return 0
      ;;
    --format=*)
      PLAYLIST_OUT_FORMAT=${1#--format=}
      AU_CONSUMED=1
      export AU_CONSUMED PLAYLIST_OUT_FORMAT
      return 0
      ;;
    --relative)
      PLAYLIST_PATH_MODE=relative
      AU_CONSUMED=1
      export AU_CONSUMED PLAYLIST_PATH_MODE
      return 0
      ;;
    --absolute)
      PLAYLIST_PATH_MODE=absolute
      AU_CONSUMED=1
      export AU_CONSUMED PLAYLIST_PATH_MODE
      return 0
      ;;
    --dedupe)
      PLAYLIST_DO_DEDUPE=1
      AU_CONSUMED=1
      export AU_CONSUMED PLAYLIST_DO_DEDUPE
      return 0
      ;;
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
    echo "Error: playlist-normalize does not support -d/-D" >&2
    return 1
  fi
  if [[ -n "${PLAYLIST_OUT_FORMAT}" ]]; then
    case "${PLAYLIST_OUT_FORMAT}" in
      m3u|m3u8|pls|xspf) ;;
      *)
        echo "Error: --format must be m3u, pls, or xspf" >&2
        return 1
        ;;
    esac
  fi
  case "${PLAYLIST_PATH_MODE}" in
    relative|absolute) ;;
    *)
      echo "Error: path mode must be relative or absolute" >&2
      return 1
      ;;
  esac
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
  local fmt="${PLAYLIST_OUT_FORMAT:-same}"
  log_always "mode:      normalize (format=${fmt} paths=${PLAYLIST_PATH_MODE} dedupe=${PLAYLIST_DO_DEDUPE})"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP AU_SOURCE_EXTS \
    PLAYLIST_OUT_FORMAT PLAYLIST_PATH_MODE PLAYLIST_DO_DEDUPE PLAYLIST_DEDUPE_BY
}
