#!/usr/bin/env bash
# dvd-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-dvd-to-flac}"
AU_SOURCE_EXT=vob
AU_DEST_EXT=flac
AU_DISK_FACTOR=4
AU_WORKDIR_PREFIX=dvd2flac
AU_SUCCESS_COLUMNS='timestamp,vob,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
AU_CLEANUP_SKIP=1
export AU_CLEANUP_SKIP
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_ROOT}/lib/load.sh"
# shellcheck source=convert.sh
source "${_LIB}/convert.sh"

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  dvd_require_css
}

plugin_export_env() {
  export DELETE_SOURCE
  export AU_CLEANUP_SKIP
}
