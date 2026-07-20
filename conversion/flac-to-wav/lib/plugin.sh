#!/usr/bin/env bash
# flac-to-wav plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-wav}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=wav
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=flac2wav
AU_SUCCESS_COLUMNS='timestamp,flac,wav,audio_md5,wav_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { pcm_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { flac_to_pcm_convert_one "$@"; }
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_export_env() { export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"; }
