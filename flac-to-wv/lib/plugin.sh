#!/usr/bin/env bash
# flac-to-wv plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-wv}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=wv
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2wv
AU_SUCCESS_COLUMNS='timestamp,flac,wv,audio_md5,wv_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_LOSSLESS_CODEC=wavpack

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { is_wavpack_pure "$2" && sibling_matches_source "$1" "$2"; }
plugin_post_encode_ok() { is_wavpack_pure "$1"; }
convert_one() { from_flac_lossless_convert_one "$@"; }
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_export_env() { export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE" AU_LOSSLESS_CODEC; }
