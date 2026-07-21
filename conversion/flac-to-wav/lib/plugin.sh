#!/usr/bin/env bash
# flac-to-wav plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-wav}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=wav
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=flac2wav
AU_SUCCESS_COLUMNS='timestamp,flac,wav,audio_md5,wav_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_sibling_ok() { pcm_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { flac_to_pcm_convert_one "$@"; }
plugin_export_env() { export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"; }
