#!/usr/bin/env bash
# flac-replaygain plugin — ReplayGain 2.0 via rsgain or loudgain.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-replaygain}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacrg
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="T"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

RG_TRACK_ONLY="${RG_TRACK_ONLY:-0}"
RG_BACKEND="${RG_BACKEND:-}"

plugin_parse_opt() {
  case "$1" in
    T)
      RG_TRACK_ONLY=1
      export RG_TRACK_ONLY
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --track)
      RG_TRACK_ONLY=1
      AU_CONSUMED=1
      export AU_CONSUMED RG_TRACK_ONLY
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-replaygain does not support -d/-D" >&2
    return 1
  fi
  if command -v rsgain >/dev/null 2>&1; then
    RG_BACKEND=rsgain
  elif command -v loudgain >/dev/null 2>&1; then
    RG_BACKEND=loudgain
  else
    echo "Error: need rsgain (preferred) or loudgain in PATH" >&2
    return 1
  fi
  export RG_BACKEND
  return 0
}

plugin_require_deps() {
  require_cmds flac flock metaflac
  [[ -n "${RG_BACKEND:-}" ]] || return 1
  require_cmds "$RG_BACKEND"
}

plugin_banner_extra() {
  if [[ "${RG_TRACK_ONLY:-0}" -eq 1 ]]; then
    log_always "mode:      track (${RG_BACKEND})"
  else
    log_always "mode:      album+track (${RG_BACKEND})"
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    log_always "existing:  rewrite"
  else
    log_always "existing:  skip"
  fi
}

plugin_export_env() {
  if [[ -z "${AU_RG_STATE_DIR:-}" ]]; then
    AU_RG_STATE_DIR=$(audio_utils_mktemp_d "rgstate.XXXXXX")
    register_tmpdir "$AU_RG_STATE_DIR"
  fi
  export AU_RG_STATE_DIR RG_TRACK_ONLY RG_BACKEND AU_CLEANUP_SKIP
}
