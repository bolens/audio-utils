#!/usr/bin/env bash
# flac-to-tta plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-tta}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=tta
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2tta
AU_SUCCESS_COLUMNS='timestamp,flac,tta,audio_md5,tta_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_LOSSLESS_CODEC=tta

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { is_tta "$2" && sibling_matches_source "$1" "$2"; }

convert_one() { from_flac_lossless_convert_one "$@"; }
plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  require_ffmpeg_encoder "$AU_LOSSLESS_CODEC"
}
plugin_export_env() { export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE" AU_LOSSLESS_CODEC; }
