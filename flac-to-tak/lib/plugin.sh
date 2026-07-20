#!/usr/bin/env bash
# flac-to-tak plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-tak}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=tak
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2tak
AU_SUCCESS_COLUMNS='timestamp,flac,tak,audio_md5,tak_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="Q:"

QUALITY_CLI="${QUALITY_CLI:-}"
TAK_PRESET="${TAK_PRESET:-}"

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_ROOT}/lib/load.sh"

plugin_sibling_ok() { sibling_matches_source "$1" "$2"; }
# shellcheck source=convert.sh
source "${_LIB}/convert.sh"

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
  TAK_PRESET="${QUALITY_CLI:-${AUDIO_UTILS_TAK_PRESET:-p2}}"
  TAK_PRESET="${TAK_PRESET,,}"
  if ! takc_preset_ok "$TAK_PRESET"; then
    log_err "Error: invalid TAK preset '$TAK_PRESET' (expected p0–p5 with optional e/m)"
    return 1
  fi
  export TAK_PRESET
}

plugin_banner_extra() {
  log_always "tak preset: $TAK_PRESET"
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  takc_resolve
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
  export TAK_PRESET
  # Re-resolve in workers
  export AUDIO_UTILS_TAKC
}
