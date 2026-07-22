#!/usr/bin/env bash
# rip-log-audit — validate CD ripper logs (EAC / XLD / Whipper / CUETools).

AU_TOOL_NAME="${AU_TOOL_NAME:-rip-log-audit}"
AU_SOURCE_EXT=log
AU_DEST_EXT=log
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=riplogaudit
AU_SUCCESS_COLUMNS='timestamp,log,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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

RIPLOG_STRICT="${RIPLOG_STRICT:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --strict)
      RIPLOG_STRICT=1
      AU_CONSUMED=1
      export AU_CONSUMED RIPLOG_STRICT
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: rip-log-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: rip-log-audit is read-only; -y is not supported" >&2
    return 1
  fi
  export RIPLOG_STRICT
  return 0
}

plugin_require_deps() {
  require_cmds flock grep awk
  command -v iconv >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  if [[ "${RIPLOG_STRICT:-0}" -eq 1 ]]; then
    log_always "mode:      rip log audit (strict AccurateRip / CRCs)"
  else
    log_always "mode:      rip log audit (EAC / XLD / Whipper / CUETools)"
  fi
}

plugin_export_env() {
  export RIPLOG_STRICT AU_CLEANUP_SKIP
}
