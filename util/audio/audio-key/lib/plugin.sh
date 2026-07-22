#!/usr/bin/env bash
# audio-key — detect musical key, save as INITIALKEY tag (multi-format).

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-key}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc spx aac"
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=audiokey
AU_SUCCESS_COLUMNS='timestamp,file,mode,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="C"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

KEY_NOTATION="${KEY_NOTATION:-standard}"

plugin_parse_opt() {
  case "$1" in
    C) KEY_NOTATION=camelot; export KEY_NOTATION; return 0 ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --camelot)
      KEY_NOTATION=camelot; AU_CONSUMED=1
      export AU_CONSUMED KEY_NOTATION; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-key does not support -d/-D" >&2
    return 1
  fi
  if ! command -v keyfinder-cli >/dev/null 2>&1; then
    echo "Error: need keyfinder-cli in PATH" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock keyfinder-cli
  command -v metaflac >/dev/null 2>&1 || true
  return 0
}

plugin_banner_extra() {
  log_always "mode:      tag key (keyfinder-cli, ${KEY_NOTATION})"
}

plugin_export_env() {
  export KEY_NOTATION AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
