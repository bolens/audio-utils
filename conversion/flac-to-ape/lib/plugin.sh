#!/usr/bin/env bash
# flac-to-ape plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-ape}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=ape
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2ape
AU_SUCCESS_COLUMNS='timestamp,flac,ape,audio_md5,ape_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="Q:"

QUALITY_CLI="${QUALITY_CLI:-}"
APE_LEVEL="${APE_LEVEL:-}"

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_sibling_ok() { is_ape "$2" && sibling_matches_source "$1" "$2"; }

plugin_consume_arg() {
  case "$1" in
    --quality)
      (($# >= 2)) || { echo "Error: --quality needs a value" >&2; exit 2; }
      QUALITY_CLI=$2
      AU_CONSUMED=2
      export AU_CONSUMED
      return 0
      ;;
    --quality=*)
      QUALITY_CLI=${1#--quality=}
      AU_CONSUMED=1
      export AU_CONSUMED
      return 0
      ;;
  esac
  return 1
}

plugin_parse_opt() {
  local opt=$1 arg=${2:-}
  case "$opt" in
    Q)
      QUALITY_CLI=$arg
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

plugin_after_flags() {
  APE_LEVEL="${QUALITY_CLI:-${AUDIO_UTILS_APE_LEVEL:-normal}}"
  APE_LEVEL="${APE_LEVEL,,}"
  if ! ape_level_ok "$APE_LEVEL"; then
    log_err "Error: invalid APE level '$APE_LEVEL' (fast|normal|high|extrahigh|insane or 1000-5000)"
    return 1
  fi
  export APE_LEVEL
}

plugin_banner_extra() {
  log_always "ape level: $APE_LEVEL"
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  mac_resolve
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
  export APE_LEVEL
  # Re-resolve in workers
  export AUDIO_UTILS_MAC
}
