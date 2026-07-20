#!/usr/bin/env bash
# cue-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-cue-to-flac}"
AU_SOURCE_EXT=cue
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=cue2flac
AU_SUCCESS_COLUMNS='timestamp,cue,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"


plugin_export_env() {
  export DELETE_SOURCE
  export AU_CLEANUP_SKIP
}
