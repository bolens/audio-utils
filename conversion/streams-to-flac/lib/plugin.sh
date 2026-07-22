#!/usr/bin/env bash
# streams-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-streams-to-flac}"
AU_SOURCE_EXT=mkv
AU_SOURCE_EXTS="mkv mka mp4 mov ts m2ts aob"
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=streams2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
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

# Accept any file with at least one audio stream (extract all, even if only 1).
plugin_accept_source() {
  local n
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$1" 2>/dev/null | grep -c . || true)
  ((n >= 1))
}

# -d deletes the container in convert.sh; -D sibling cleanup is not used here.
plugin_after_flags() {
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: streams-to-flac does not support -D (use -d to delete the container)" >&2
    return 1
  fi
  return 0
}

plugin_export_env() {
  export DELETE_SOURCE
  export AU_CLEANUP_SKIP
}
