#!/usr/bin/env bash
# wav-to-flac plugin: contract + tool modules for the shared driver.

AU_TOOL_NAME="${AU_TOOL_NAME:-wav-to-flac}"
AU_SOURCE_EXT=wav
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=wav2flac
AU_SUCCESS_COLUMNS='timestamp,wav,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="cR"

CLEAN_WAV="${CLEAN_WAV:-0}"
RETAG_ONLY="${RETAG_ONLY:-0}"

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2"; }

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
