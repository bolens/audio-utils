#!/usr/bin/env bash
# audio-compare — compare a file to the same relative path under --against.

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-compare}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac wav aiff aif mp3 opus m4a ogg oga wma mpc spx aac wv ape tak tta"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=audiocmp
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

# md5 = decode audio MD5; streaminfo = FLAC STREAMINFO only; peak = abs peak delta
COMPARE_MODE="${COMPARE_MODE:-md5}"
COMPARE_AGAINST="${COMPARE_AGAINST:-}"
COMPARE_PEAK_EPS="${COMPARE_PEAK_EPS:-0.001}"

plugin_consume_arg() {
  case "${1:-}" in
    --against=*)
      COMPARE_AGAINST="${1#--against=}"; AU_CONSUMED=1
      export AU_CONSUMED COMPARE_AGAINST; return 0 ;;
    --against)
      [[ -n "${2:-}" ]] || { echo "Error: --against needs a path" >&2; return 1; }
      COMPARE_AGAINST=$2; AU_CONSUMED=2
      export AU_CONSUMED COMPARE_AGAINST; return 0 ;;
    --mode=*)
      COMPARE_MODE="${1#--mode=}"; AU_CONSUMED=1
      export AU_CONSUMED COMPARE_MODE; return 0 ;;
    --mode)
      [[ -n "${2:-}" ]] || { echo "Error: --mode needs md5|streaminfo|peak" >&2; return 1; }
      COMPARE_MODE=$2; AU_CONSUMED=2
      export AU_CONSUMED COMPARE_MODE; return 0 ;;
    --peak-eps=*)
      COMPARE_PEAK_EPS="${1#--peak-eps=}"; AU_CONSUMED=1
      export AU_CONSUMED COMPARE_PEAK_EPS; return 0 ;;
    --peak-eps)
      [[ -n "${2:-}" ]] || { echo "Error: --peak-eps needs a number" >&2; return 1; }
      COMPARE_PEAK_EPS=$2; AU_CONSUMED=2
      export AU_CONSUMED COMPARE_PEAK_EPS; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-compare does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: audio-compare does not support -y" >&2
    return 1
  fi
  if [[ -z "${COMPARE_AGAINST}" ]]; then
    echo "Error: --against=DIR is required" >&2
    return 1
  fi
  if [[ ! -d "${COMPARE_AGAINST}" ]]; then
    echo "Error: --against is not a directory: ${COMPARE_AGAINST}" >&2
    return 1
  fi
  COMPARE_AGAINST=$(cd -- "${COMPARE_AGAINST}" && pwd)
  case "${COMPARE_MODE}" in
    md5 | streaminfo | peak) ;;
    *)
      echo "Error: invalid --mode '${COMPARE_MODE}' (md5|streaminfo|peak)" >&2
      return 1
      ;;
  esac
  export COMPARE_AGAINST COMPARE_MODE COMPARE_PEAK_EPS
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  case "${COMPARE_MODE}" in
    streaminfo) require_cmds metaflac ;;
  esac
}

plugin_banner_extra() {
  log_always "mode:      compare (${COMPARE_MODE}) vs ${COMPARE_AGAINST}"
}

plugin_export_env() {
  export COMPARE_AGAINST COMPARE_MODE COMPARE_PEAK_EPS AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
