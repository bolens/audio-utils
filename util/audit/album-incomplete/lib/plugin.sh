#!/usr/bin/env bash
# album-incomplete — completeness vs TOTALTRACKS / TOTALDISCS / duration outliers.

AU_TOOL_NAME="${AU_TOOL_NAME:-album-incomplete}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=albumincomp
AU_SUCCESS_COLUMNS='timestamp,dir,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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

INCOMPLETE_DUR_RATIO="${INCOMPLETE_DUR_RATIO:-0.35}"
INCOMPLETE_NO_DURATION="${INCOMPLETE_NO_DURATION:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --duration-ratio=*)
      INCOMPLETE_DUR_RATIO="${1#--duration-ratio=}"
      AU_CONSUMED=1
      export AU_CONSUMED INCOMPLETE_DUR_RATIO
      return 0
      ;;
    --duration-ratio)
      [[ -n "${2:-}" ]] || { echo "Error: --duration-ratio needs a value" >&2; return 1; }
      INCOMPLETE_DUR_RATIO=$2
      AU_CONSUMED=2
      export AU_CONSUMED INCOMPLETE_DUR_RATIO
      return 0
      ;;
    --no-duration)
      INCOMPLETE_NO_DURATION=1
      AU_CONSUMED=1
      export AU_CONSUMED INCOMPLETE_NO_DURATION
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: album-incomplete is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: album-incomplete is read-only; -y is not supported" >&2
    return 1
  fi
  if ! awk -v r="${INCOMPLETE_DUR_RATIO}" 'BEGIN { exit !(r+0 > 0 && r+0 < 1) }'; then
    echo "Error: --duration-ratio must be between 0 and 1 (got ${INCOMPLETE_DUR_RATIO})" >&2
    return 1
  fi
  export INCOMPLETE_DUR_RATIO INCOMPLETE_NO_DURATION
  return 0
}

plugin_require_deps() {
  require_cmds ffprobe flock awk
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  if [[ "${INCOMPLETE_NO_DURATION:-0}" -eq 1 ]]; then
    log_always "mode:      album completeness (tracks/discs; no duration outliers)"
  else
    log_always "mode:      album completeness (tracks/discs; duration ratio=${INCOMPLETE_DUR_RATIO})"
  fi
}

plugin_export_env() {
  if [[ -z "${AU_INCOMP_STATE:-}" ]]; then
    AU_INCOMP_STATE=$(audio_utils_mktemp_d "albumincomp.XXXXXX")
    register_tmpdir "$AU_INCOMP_STATE"
  fi
  export AU_INCOMP_STATE AU_CLEANUP_SKIP AU_SOURCE_EXTS \
    INCOMPLETE_DUR_RATIO INCOMPLETE_NO_DURATION
}
