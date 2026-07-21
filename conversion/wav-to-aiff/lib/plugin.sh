#!/usr/bin/env bash
# wav-to-aiff plugin — shared PCM remux pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-wav-to-aiff}"
AU_SOURCE_EXT=wav
AU_DEST_EXT=aiff
AU_DISK_FACTOR=1.2
AU_WORKDIR_PREFIX=wav2aiff
AU_SUCCESS_COLUMNS='timestamp,wav,aiff,audio_md5,aiff_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=wav

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

convert_one() { pcm_remux_convert_one "$@"; }
plugin_sibling_ok() { pcm_ok "$2" && sibling_matches_source "$1" "$2"; }

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_export_env() {
  export DELETE_SOURCE AU_SOURCE_LABEL
}
