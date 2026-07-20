#!/usr/bin/env bash
# flac-to-mp3 plugin: contract + tool modules for the shared driver.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-mp3}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=mp3
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2mp3
AU_SUCCESS_COLUMNS='timestamp,flac,mp3,src_audio_md5,mp3_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

QUALITY_CLI="${QUALITY_CLI:-}"
LOSSY_NO_RESAMPLE="${LOSSY_NO_RESAMPLE:-0}"

_FLAC2MP3_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_FLAC2MP3_LIB_DIR}/.." && pwd)
_AUDIO_UTILS_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"

# shellcheck source=quality.sh
source "${_FLAC2MP3_LIB_DIR}/quality.sh"
# shellcheck source=success_log.sh
source "${_FLAC2MP3_LIB_DIR}/success_log.sh"
# shellcheck source=encode.sh
source "${_FLAC2MP3_LIB_DIR}/encode.sh"
# shellcheck source=convert.sh
source "${_FLAC2MP3_LIB_DIR}/convert.sh"
# shellcheck source=cleanup.sh
source "${_FLAC2MP3_LIB_DIR}/cleanup.sh"

if [[ -n "${MP3_FF_ARGS_STR:-}" ]]; then
  # shellcheck disable=SC2206
  MP3_FF_ARGS=($MP3_FF_ARGS_STR)
fi

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
    --no-resample)
      LOSSY_NO_RESAMPLE=1
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
    N)
      LOSSY_NO_RESAMPLE=1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  require_libmp3lame
}

plugin_after_flags() {
  local raw="${QUALITY_CLI:-${FLAC2MP3_QUALITY:-${AUDIO_UTILS_MP3_QUALITY:-v0}}}"
  mp3_resolve_quality "$raw" || return 1
  export MP3_QUALITY_NAME LOSSY_NO_RESAMPLE
  export MP3_FF_ARGS_STR="${MP3_FF_ARGS[*]}"
}

plugin_banner_extra() {
  log_always "quality:   $MP3_QUALITY_NAME (${MP3_FF_ARGS[*]})"
  if [[ "${LOSSY_NO_RESAMPLE:-0}" -eq 1 ]]; then
    log_always "resample:  disabled (-N)"
  fi
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
  export MP3_QUALITY_NAME MP3_FF_ARGS_STR LOSSY_NO_RESAMPLE
}
