#!/usr/bin/env bash
# flac-to-alac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-alac}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=m4a
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2alac
AU_SUCCESS_COLUMNS='timestamp,flac,m4a,audio_md5,m4a_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_LOSSLESS_CODEC=alac

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { is_alac "$2" && sibling_matches_source "$1" "$2"; }

convert_one() { from_flac_lossless_convert_one "$@"; }
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_export_env() { export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE" AU_LOSSLESS_CODEC; }
