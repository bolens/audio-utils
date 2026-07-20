#!/usr/bin/env bash
# streams-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-streams-to-flac}"
AU_SOURCE_EXT=mkv
AU_SOURCE_EXTS="mkv mka mp4 mov ts m2ts aob"
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=streams2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

# Accept any file with at least one audio stream (extract all, even if only 1).
plugin_accept_source() {
  local n
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$1" 2>/dev/null | grep -c . || true)
  ((n >= 1))
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock
}

plugin_export_env() {
  export DELETE_SOURCE
  export AU_CLEANUP_SKIP
}
