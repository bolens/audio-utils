#!/usr/bin/env bash
# aiff-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-aiff-to-flac}"
AU_SOURCE_EXT=aiff
AU_SOURCE_EXTS="aiff aif"
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=aiff2flac
AU_SUCCESS_COLUMNS='timestamp,aiff,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="cR"

CLEAN_WAV="${CLEAN_WAV:-0}"
RETAG_ONLY="${RETAG_ONLY:-0}"

_AIFF2FLAC_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_AIFF2FLAC_LIB_DIR}/.." && pwd)
_AUDIO_UTILS_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_SOURCE_EXTS AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"

plugin_sibling_ok() { flac_ok "$2"; }
# shellcheck source=convert.sh
source "${_AIFF2FLAC_LIB_DIR}/convert.sh"

plugin_parse_opt() {
  local opt=$1
  case "$opt" in
    c) CLEAN_WAV=1; return 0 ;;
    R) RETAG_ONLY=1; return 0 ;;
    *) return 1 ;;
  esac
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 && "$CLEAN_WAV" -eq 1 ]]; then
    echo "Note: -d set; -c ignored (source will be deleted, not cleaned)." >&2
    CLEAN_WAV=0
  fi
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    if [[ "$RETAG_ONLY" -eq 1 || "$CLEAN_WAV" -eq 1 ]]; then
      echo "Note: -D is cleanup-only; -R/-c ignored." >&2
    fi
    RETAG_ONLY=0
    CLEAN_WAV=0
  fi
  if [[ "$RETAG_ONLY" -eq 1 && ( "${DELETE_SOURCE:-0}" -eq 1 || "$CLEAN_WAV" -eq 1 ) ]]; then
    echo "Note: -R set; -d/-c ignored." >&2
    DELETE_SOURCE=0
    CLEAN_WAV=0
  fi
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE"
  export CLEAN_WAV RETAG_ONLY
}
