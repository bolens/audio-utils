#!/usr/bin/env bash
# silence-detect — leading/trailing silence and clip peaks.

AU_TOOL_NAME="${AU_TOOL_NAME:-silence-detect}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc aac wav aiff aif"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=silencedet
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

SILENCE_SEC="${SILENCE_SEC:-1.0}"
SILENCE_DB="${SILENCE_DB:--50}"
CLIP_FAIL="${CLIP_FAIL:-1}"

plugin_consume_arg() {
  case "${1:-}" in
    --silence-sec=*)
      SILENCE_SEC="${1#--silence-sec=}"; AU_CONSUMED=1
      export AU_CONSUMED SILENCE_SEC; return 0 ;;
    --silence-db=*)
      SILENCE_DB="${1#--silence-db=}"; AU_CONSUMED=1
      export AU_CONSUMED SILENCE_DB; return 0 ;;
    --no-clip)
      CLIP_FAIL=0; AU_CONSUMED=1
      export AU_CONSUMED CLIP_FAIL; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: silence-detect is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: silence-detect is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock awk
}

plugin_banner_extra() {
  log_always "silence:   ${SILENCE_SEC}s @ ${SILENCE_DB}dB"
}

plugin_export_env() {
  export SILENCE_SEC SILENCE_DB CLIP_FAIL AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
