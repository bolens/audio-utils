#!/usr/bin/env bash
# junk-cleanup — OS litter and zero-byte files in audio directories.

AU_TOOL_NAME="${AU_TOOL_NAME:-junk-cleanup}"
AU_SOURCE_EXT=db
AU_SOURCE_EXTS="db ini ds_store directory flac mp3 opus m4a ogg oga wma mpc spx aac wav aiff aif caf wv ape tak tta cue m3u m3u8 pls xspf jpg jpeg png log"
AU_DEST_EXT=db
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=junkclean
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

JUNK_DELETE="${JUNK_DELETE:-0}"

plugin_after_flags() {
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: junk-cleanup does not support -D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: junk-cleanup does not support -y" >&2
    return 1
  fi
  # Map shared -d to "delete junk"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    JUNK_DELETE=1
    DELETE_SOURCE=0
  fi
  export JUNK_DELETE
  return 0
}

plugin_require_deps() {
  require_cmds flock
}

# Queue only actual junk; everything else in the ext sweep is skipped.
plugin_accept_source() {
  _junk_reason "$1" >/dev/null
}

plugin_banner_extra() {
  if [[ "${JUNK_DELETE:-0}" -eq 1 ]]; then
    log_always "mode:      delete junk files"
  else
    log_always "mode:      report junk files (use -d to delete)"
  fi
}

plugin_export_env() {
  export JUNK_DELETE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
