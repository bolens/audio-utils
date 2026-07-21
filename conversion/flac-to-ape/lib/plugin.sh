#!/usr/bin/env bash
# flac-to-ape plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-ape}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=ape
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2ape
AU_SUCCESS_COLUMNS='timestamp,flac,ape,audio_md5,ape_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_LOSSLESS_CODEC=ape

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_sibling_ok() { is_ape "$2" && sibling_matches_source "$1" "$2"; }

convert_one() { from_flac_lossless_convert_one "$@"; }
plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  require_ffmpeg_encoder "$AU_LOSSLESS_CODEC"
}
plugin_export_env() { export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE" AU_LOSSLESS_CODEC; }
