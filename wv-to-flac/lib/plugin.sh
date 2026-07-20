#!/usr/bin/env bash
# wv-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-wv-to-flac}"
AU_SOURCE_EXT=wv
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=wv2flac
AU_SUCCESS_COLUMNS='timestamp,wv,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=wv

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { to_flac_convert_one "$@"; }
plugin_accept_source() { is_wavpack_pure "$1"; }
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_export_env() { export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE" AU_SOURCE_LABEL; }

