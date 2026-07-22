#!/usr/bin/env bash
# cue-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-cue-to-flac}"
AU_SOURCE_EXT=cue
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=cue2flac
AU_SUCCESS_COLUMNS='timestamp,cue,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

# CUE sheet is kept; splitting does not delete the .cue.
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: cue-to-flac does not support -d/-D (CUE sheet is kept)" >&2
    return 1
  fi
  return 0
}

plugin_export_env() {
  export AU_CLEANUP_SKIP
}
