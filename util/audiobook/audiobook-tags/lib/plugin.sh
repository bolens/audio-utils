#!/usr/bin/env bash
# audiobook-tags — normalize author/narrator/series tags for audiobooks.

AU_TOOL_NAME="${AU_TOOL_NAME:-audiobook-tags}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=abooktags
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$(au_audio_exts_for_preset audiobook)
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

ABOOK_APPLY="${ABOOK_APPLY:-0}"
ABOOK_ONLY="${ABOOK_ONLY:-1}"

plugin_consume_arg() {
  case "${1:-}" in
    --apply)
      ABOOK_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED ABOOK_APPLY; return 0 ;;
    --all-genres)
      ABOOK_ONLY=0; AU_CONSUMED=1
      export AU_CONSUMED ABOOK_ONLY; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audiobook-tags does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: audiobook-tags does not support -y (use --apply)" >&2
    return 1
  fi
  export ABOOK_APPLY ABOOK_ONLY
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  local mode="report audiobook tags"
  [[ "${ABOOK_APPLY:-0}" -eq 1 ]] && mode="apply audiobook tag normalize"
  [[ "${ABOOK_ONLY:-1}" -eq 0 ]] && mode+="; all genres"
  log_always "mode:      $mode"
}

plugin_export_env() {
  export ABOOK_APPLY ABOOK_ONLY AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
