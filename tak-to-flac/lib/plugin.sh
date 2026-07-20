#!/usr/bin/env bash
# tak-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-tak-to-flac}"
AU_SOURCE_EXT=tak
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=tak2flac
AU_SUCCESS_COLUMNS='timestamp,tak,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=tak
AU_TAG_FROM_SOURCE=1

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
plugin_decode_prep() {
  local src=$1 tmpdir=$2 wav="${2}/decoded.wav"
  tak_decode_to_wav "$src" "$tmpdir" "$wav" || return 1
  printf '%s\n' "$wav"
}
convert_one() { to_flac_convert_one "$@"; }

plugin_accept_source() {
  local c
  c=$(audio_codec "$1" 2>/dev/null || true)
  [[ "$c" == "tak" || "${1,,}" == *.tak ]]
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock
}

plugin_export_env() {
  export DELETE_SOURCE AU_SOURCE_LABEL AU_TAG_FROM_SOURCE
}
