#!/usr/bin/env bash
# disc-inventory — catalog VIDEO_TS / BDMV / CUE units under roots.

AU_TOOL_NAME="${AU_TOOL_NAME:-disc-inventory}"
AU_SOURCE_EXT=ifo
AU_SOURCE_EXTS="ifo bdmv cue"
AU_DEST_EXT=ifo
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=discinv
AU_SUCCESS_COLUMNS='timestamp,unit,kind,audio_md5,file_sha256,codec,bytes,samples,notes'
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

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: disc-inventory is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: disc-inventory is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flock
}

plugin_accept_source() {
  local f=$1 base dir
  base=$(basename -- "$f")
  dir=$(dirname -- "$f")
  case "${base,,}" in
    video_ts.ifo) return 0 ;;
    index.bdmv) return 0 ;;
    *.cue) return 0 ;;
    *)
      # Accept any .ifo inside a VIDEO_TS dir once via convert lock
      if [[ "${f,,}" == *.ifo && "$(basename -- "$dir")" == "VIDEO_TS" ]]; then
        return 0
      fi
      return 1
      ;;
  esac
}

plugin_banner_extra() {
  log_always "mode:      inventory VIDEO_TS / BDMV / CUE"
}

plugin_export_env() {
  if [[ -z "${AU_DISCINV_STATE:-}" ]]; then
    AU_DISCINV_STATE=$(audio_utils_mktemp_d "discinv.XXXXXX")
    register_tmpdir "$AU_DISCINV_STATE"
  fi
  export AU_DISCINV_STATE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}

plugin_finalize() {
  local rows="${AU_DISCINV_STATE:-}/units.tsv"
  [[ -f "$rows" ]] || { log_always "Disc units: 0"; return 0; }
  log_always "Disc units found:"
  awk -F'\t' '{printf "  %-10s %s\n", $1, $2}' "$rows" | LC_ALL=C sort
}
