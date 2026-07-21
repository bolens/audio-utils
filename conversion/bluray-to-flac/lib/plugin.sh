#!/usr/bin/env bash
# bluray-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-bluray-to-flac}"
AU_SOURCE_EXT=m2ts
AU_DEST_EXT=flac
AU_DISK_FACTOR=4
AU_WORKDIR_PREFIX=bluray2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="D:"

AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

# libbluray/libaacs/MakeMKV are optional (hybrid) — checked per-input in lib/bluray.sh.
plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe
}

plugin_export_env() {
  export DELETE_SOURCE
  export AUDIO_UTILS_BD_DEVICE AUDIO_UTILS_MAKEMKV
  export AU_CLEANUP_SKIP
}
