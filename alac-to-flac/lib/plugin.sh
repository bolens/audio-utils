#!/usr/bin/env bash
# alac-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-alac-to-flac}"
AU_SOURCE_EXT=m4a
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=alac2flac
AU_SUCCESS_COLUMNS='timestamp,m4a,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=m4a

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { to_flac_convert_one "$@"; }
plugin_accept_source() { is_alac "$1"; }
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_export_env() { export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE" AU_SOURCE_LABEL; }

