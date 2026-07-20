#!/usr/bin/env bash
# caf-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-caf-to-flac}"
AU_SOURCE_EXT=caf
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=caf2flac
AU_SUCCESS_COLUMNS='timestamp,caf,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=caf

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { to_flac_convert_one "$@"; }
plugin_accept_source() {
  local n
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$1" 2>/dev/null | grep -c . || true)
  ((n >= 1))
}
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_export_env() { export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE" AU_SOURCE_LABEL; }
