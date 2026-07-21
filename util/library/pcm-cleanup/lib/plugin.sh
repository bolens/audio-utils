#!/usr/bin/env bash
# pcm-cleanup — find leftover PCM beside verified FLAC siblings.

AU_TOOL_NAME="${AU_TOOL_NAME:-pcm-cleanup}"
AU_SOURCE_EXT=wav
AU_SOURCE_EXTS="wav aiff aif caf"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=pcmclean
AU_SUCCESS_COLUMNS='timestamp,pcm,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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

# Use shared -d as delete-after-verify
PCM_DELETE="${PCM_DELETE:-0}"

plugin_after_flags() {
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: pcm-cleanup does not support -D" >&2
    return 1
  fi
  # Map -d to delete verified leftover PCM
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    PCM_DELETE=1
    DELETE_SOURCE=0
  fi
  export PCM_DELETE
  return 0
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock
}

plugin_banner_extra() {
  if [[ "${PCM_DELETE:-0}" -eq 1 ]]; then
    log_always "mode:      delete PCM when FLAC sibling verifies"
  else
    log_always "mode:      report leftover PCM (use -d to delete)"
  fi
}

plugin_export_env() {
  export PCM_DELETE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
