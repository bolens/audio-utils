#!/usr/bin/env bash
# chapters — list / extract / embed chapter markers on .m4b / .m4a.

AU_TOOL_NAME="${AU_TOOL_NAME:-chapters}"
AU_SOURCE_EXT=m4b
AU_DEST_EXT=m4b
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=chapters
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
AU_SOURCE_EXTS="m4b m4a"
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

CHAPTERS_EXTRACT="${CHAPTERS_EXTRACT:-}"
CHAPTERS_EMBED="${CHAPTERS_EMBED:-}"
CHAPTERS_APPLY="${CHAPTERS_APPLY:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --extract=*)
      CHAPTERS_EXTRACT=${1#--extract=}
      AU_CONSUMED=1
      export AU_CONSUMED CHAPTERS_EXTRACT
      return 0
      ;;
    --extract)
      CHAPTERS_EXTRACT="${2:-}"
      AU_CONSUMED=2
      export AU_CONSUMED CHAPTERS_EXTRACT
      return 0
      ;;
    --embed=*)
      CHAPTERS_EMBED=${1#--embed=}
      AU_CONSUMED=1
      export AU_CONSUMED CHAPTERS_EMBED
      return 0
      ;;
    --embed)
      CHAPTERS_EMBED="${2:-}"
      AU_CONSUMED=2
      export AU_CONSUMED CHAPTERS_EMBED
      return 0
      ;;
    --apply)
      CHAPTERS_APPLY=1
      AU_CONSUMED=1
      export AU_CONSUMED CHAPTERS_APPLY
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: chapters does not support -d/-D" >&2
    return 1
  fi
  if [[ -n "${CHAPTERS_EMBED:-}" && "${CHAPTERS_APPLY:-0}" -ne 1 && "${OVERWRITE:-0}" -ne 1 ]]; then
    echo "Error: --embed requires --apply (or -y)" >&2
    return 1
  fi
  if [[ -n "${CHAPTERS_EXTRACT:-}" && -n "${CHAPTERS_EMBED:-}" ]]; then
    echo "Error: use only one of --extract / --embed" >&2
    return 1
  fi
  if [[ -n "${CHAPTERS_EMBED:-}" && ! -f "${CHAPTERS_EMBED}" ]]; then
    echo "Error: --embed file not found: $CHAPTERS_EMBED" >&2
    return 1
  fi
  export CHAPTERS_EXTRACT CHAPTERS_EMBED CHAPTERS_APPLY
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_banner_extra() {
  local mode="list chapters"
  [[ -n "${CHAPTERS_EXTRACT:-}" ]] && mode="extract -> $CHAPTERS_EXTRACT"
  [[ -n "${CHAPTERS_EMBED:-}" ]] && mode="embed from $CHAPTERS_EMBED"
  log_always "mode:      $mode"
}

plugin_export_env() {
  export CHAPTERS_EXTRACT CHAPTERS_EMBED CHAPTERS_APPLY AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
