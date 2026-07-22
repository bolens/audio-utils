#!/usr/bin/env bash
# audio-lyrics — LYRICS tag / sidecar audit, import, export.

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-lyrics}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=lrc
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=lyrics
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
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

LYRICS_MODE="${LYRICS_MODE:-report}"

plugin_consume_arg() {
  case "${1:-}" in
    --import)
      LYRICS_MODE="import"; AU_CONSUMED=1
      export AU_CONSUMED LYRICS_MODE; return 0 ;;
    --export)
      LYRICS_MODE="export"; AU_CONSUMED=1
      export AU_CONSUMED LYRICS_MODE; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-lyrics does not support -d/-D" >&2
    return 1
  fi
  case "$LYRICS_MODE" in
    report | import | export) ;;
    *)
      echo "Error: bad lyrics mode: $LYRICS_MODE" >&2
      return 1
      ;;
  esac
  return 0
}

plugin_require_deps() {
  require_cmds ffprobe flock
  if [[ "$LYRICS_MODE" == import ]]; then
    require_cmds metaflac
  fi
}

plugin_banner_extra() {
  case "$LYRICS_MODE" in
    report) log_always "mode:      report files without lyrics (tag or sidecar)" ;;
    import) log_always "mode:      import sidecar → LYRICS tag (FLAC only)" ;;
    export) log_always "mode:      export LYRICS tag → <stem>.lrc sidecar" ;;
  esac
}

plugin_export_env() {
  export LYRICS_MODE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
