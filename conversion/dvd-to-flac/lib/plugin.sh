#!/usr/bin/env bash
# dvd-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-dvd-to-flac}"
AU_SOURCE_EXT=vob
AU_DEST_EXT=flac
AU_DISK_FACTOR=4
AU_WORKDIR_PREFIX=dvd2flac
AU_SUCCESS_COLUMNS='timestamp,vob,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  dvd_require_css
}

plugin_export_env() {
  export DELETE_SOURCE
  export AU_CLEANUP_SKIP
}
