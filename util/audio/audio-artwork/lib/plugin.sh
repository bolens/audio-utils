#!/usr/bin/env bash
# audio-artwork — embed/extract covers for common audio formats.

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-artwork}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=audioart
AU_SUCCESS_COLUMNS='timestamp,file,mode,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="x"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_DEFAULT
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

ART_EXTRACT="${ART_EXTRACT:-0}"

plugin_parse_opt() {
  case "$1" in
    x) ART_EXTRACT=1; export ART_EXTRACT; return 0 ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --extract) ART_EXTRACT=1; AU_CONSUMED=1; export AU_CONSUMED ART_EXTRACT; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-artwork does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_banner_extra() {
  if [[ "${ART_EXTRACT:-0}" -eq 1 ]]; then
    log_always "mode:      extract -> cover.jpg"
  else
    log_always "mode:      embed from folder cover"
  fi
}

plugin_export_env() {
  export ART_EXTRACT AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
