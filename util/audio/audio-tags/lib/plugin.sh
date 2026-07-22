#!/usr/bin/env bash
# audio-tags — normalize tags across common audio formats.

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-tags}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc spx aac"
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=audiotags
AU_SUCCESS_COLUMNS='timestamp,file,mode,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="A"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

TAGS_FILL_ALBUMARTIST="${TAGS_FILL_ALBUMARTIST:-0}"

plugin_parse_opt() {
  case "$1" in
    A) TAGS_FILL_ALBUMARTIST=1; export TAGS_FILL_ALBUMARTIST; return 0 ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --fill-albumartist)
      TAGS_FILL_ALBUMARTIST=1; AU_CONSUMED=1
      export AU_CONSUMED TAGS_FILL_ALBUMARTIST; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-tags does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  log_always "mode:      normalize tags (multi-format)"
}

plugin_export_env() {
  export TAGS_FILL_ALBUMARTIST AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
