#!/usr/bin/env bash
# lossy-audit — portable library health (tags, bitrate, cover).

AU_TOOL_NAME="${AU_TOOL_NAME:-lossy-audit}"
AU_SOURCE_EXT=mp3
AU_SOURCE_EXTS="mp3 opus m4a ogg oga wma mpc spx aac"
AU_DEST_EXT=mp3
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=lossyaudit
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

LOSSY_MIN_KBPS="${LOSSY_MIN_KBPS:-128}"

plugin_consume_arg() {
  case "${1:-}" in
    --min-kbps=*)
      LOSSY_MIN_KBPS="${1#--min-kbps=}"; AU_CONSUMED=1
      export AU_CONSUMED LOSSY_MIN_KBPS; return 0 ;;
    --min-kbps)
      [[ -n "${2:-}" ]] || { echo "Error: --min-kbps needs N" >&2; return 1; }
      LOSSY_MIN_KBPS=$2; AU_CONSUMED=2
      export AU_CONSUMED LOSSY_MIN_KBPS; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: lossy-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: lossy-audit is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_banner_extra() {
  log_always "mode:      lossy audit (tags, cover, min ${LOSSY_MIN_KBPS} kbps)"
}

plugin_export_env() {
  export LOSSY_MIN_KBPS AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
