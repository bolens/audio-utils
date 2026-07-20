#!/usr/bin/env bash
# flac-to-ape plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-ape}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=ape
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2ape
AU_SUCCESS_COLUMNS='timestamp,flac,ape,audio_md5,ape_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_ROOT}/lib/load.sh"

plugin_sibling_ok() { [[ "$(audio_codec "$2" 2>/dev/null || true)" == "ape" ]] && sibling_matches_source "$1" "$2"; }
# shellcheck source=convert.sh
source "${_LIB}/convert.sh"

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  require_ffmpeg_encoder ape
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
}
