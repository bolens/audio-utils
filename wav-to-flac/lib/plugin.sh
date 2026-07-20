#!/usr/bin/env bash
# wav-to-flac plugin: contract + tool modules for the shared driver.

AU_TOOL_NAME="${AU_TOOL_NAME:-wav-to-flac}"
AU_SOURCE_EXT=wav
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=wav2flac
AU_SUCCESS_COLUMNS='timestamp,wav,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="cR"

# Preserve values exported by the driver into parallel workers
CLEAN_WAV="${CLEAN_WAV:-0}"
RETAG_ONLY="${RETAG_ONLY:-0}"

_WAV2FLAC_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_WAV2FLAC_LIB_DIR}/.." && pwd)
_AUDIO_UTILS_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"

# shellcheck source=success_log.sh
source "${_WAV2FLAC_LIB_DIR}/success_log.sh"
# shellcheck source=prepare.sh
source "${_WAV2FLAC_LIB_DIR}/prepare.sh"
# shellcheck source=encode.sh
source "${_WAV2FLAC_LIB_DIR}/encode.sh"
# shellcheck source=convert.sh
source "${_WAV2FLAC_LIB_DIR}/convert.sh"
# shellcheck source=cleanup.sh
source "${_WAV2FLAC_LIB_DIR}/cleanup.sh"

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
    echo "Note: -d set; -c ignored (WAV will be deleted, not cleaned)." >&2
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
