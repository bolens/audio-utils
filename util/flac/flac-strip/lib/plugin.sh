#!/usr/bin/env bash
# flac-strip plugin — metadata / padding hygiene.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-strip}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacstrip
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="ck"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

STRIP_CORE_ONLY="${STRIP_CORE_ONLY:-0}"
STRIP_KEEP_PICTURE="${STRIP_KEEP_PICTURE:-1}"

plugin_parse_opt() {
  case "$1" in
    c)
      STRIP_CORE_ONLY=1
      export STRIP_CORE_ONLY
      return 0
      ;;
    k)
      STRIP_KEEP_PICTURE=0
      export STRIP_KEEP_PICTURE
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --core-tags)
      STRIP_CORE_ONLY=1
      AU_CONSUMED=1
      export AU_CONSUMED STRIP_CORE_ONLY
      return 0
      ;;
    --no-picture)
      STRIP_KEEP_PICTURE=0
      AU_CONSUMED=1
      export AU_CONSUMED STRIP_KEEP_PICTURE
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-strip does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac flock
}

plugin_banner_extra() {
  log_always "mode:      strip padding/APPLICATION$([ "${STRIP_CORE_ONLY}" -eq 1 ] && echo '; core tags only')"
  if [[ "${STRIP_KEEP_PICTURE}" -eq 0 ]]; then
    log_always "pictures:  remove"
  else
    log_always "pictures:  keep"
  fi
}

plugin_export_env() {
  export STRIP_CORE_ONLY STRIP_KEEP_PICTURE AU_CLEANUP_SKIP
}
