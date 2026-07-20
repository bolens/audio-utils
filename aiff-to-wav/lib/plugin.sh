#!/usr/bin/env bash
# aiff-to-wav plugin — shared PCM remux pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-aiff-to-wav}"
AU_SOURCE_EXT=aiff
AU_SOURCE_EXTS="aiff aif"
AU_DEST_EXT=wav
AU_DISK_FACTOR=1.2
AU_WORKDIR_PREFIX=aiff2wav
AU_SUCCESS_COLUMNS='timestamp,aiff,wav,audio_md5,wav_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=aiff

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_SOURCE_EXTS AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
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
