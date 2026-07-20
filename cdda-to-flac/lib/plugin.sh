#!/usr/bin/env bash
# cdda-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-cdda-to-flac}"
AU_SOURCE_EXT=cdda
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=cdda2flac
AU_SUCCESS_COLUMNS='timestamp,track,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

AU_CLEANUP_SKIP=1

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  cdda_require
}

plugin_export_env() {
  export DELETE_SOURCE
  export AU_CLEANUP_SKIP
}
