#!/usr/bin/env bash
# flac-to-aiff plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-aiff}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=aiff
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=flac2aiff
AU_SUCCESS_COLUMNS='timestamp,flac,aiff,audio_md5,aiff_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

_FLAC2AIFF_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_FLAC2AIFF_LIB_DIR}/.." && pwd)
_AUDIO_UTILS_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"
# shellcheck source=success_log.sh
source "${_FLAC2AIFF_LIB_DIR}/success_log.sh"
# shellcheck source=convert.sh
source "${_FLAC2AIFF_LIB_DIR}/convert.sh"
# shellcheck source=cleanup.sh
source "${_FLAC2AIFF_LIB_DIR}/cleanup.sh"

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
}
