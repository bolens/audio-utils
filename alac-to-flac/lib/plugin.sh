#!/usr/bin/env bash
# alac-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-alac-to-flac}"
AU_SOURCE_EXT=m4a
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=alac2flac
AU_SUCCESS_COLUMNS='timestamp,m4a,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_ROOT}/lib/load.sh"
# shellcheck source=success_log.sh
source "${_LIB}/success_log.sh"
# shellcheck source=convert.sh
source "${_LIB}/convert.sh"
# shellcheck source=cleanup.sh
source "${_LIB}/cleanup.sh"

plugin_accept_source() {
  is_alac "$1"
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE"
}
