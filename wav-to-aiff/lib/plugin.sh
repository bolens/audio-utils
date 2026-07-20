#!/usr/bin/env bash
# wav-to-aiff plugin — shared PCM remux pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-wav-to-aiff}"
AU_SOURCE_EXT=wav
AU_DEST_EXT=aiff
AU_DISK_FACTOR=1.2
AU_WORKDIR_PREFIX=wav2aiff
AU_SUCCESS_COLUMNS='timestamp,wav,aiff,audio_md5,aiff_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=wav

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR AU_SOURCE_LABEL
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_ROOT}/lib/load.sh"

convert_one() { pcm_remux_convert_one "$@"; }
plugin_sibling_ok() { pcm_ok "$2" && sibling_matches_source "$1" "$2"; }

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_export_env() {
  export DELETE_SOURCE AU_SOURCE_LABEL
}
