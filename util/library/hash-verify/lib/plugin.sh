#!/usr/bin/env bash
# hash-verify — verify or write sidecar checksums.

AU_TOOL_NAME="${AU_TOOL_NAME:-hash-verify}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=hashverify
AU_SUCCESS_COLUMNS='timestamp,file,mode,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="w"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS="$AU_AUDIO_EXTS_DEFAULT $AU_AUDIO_EXTS_PCM"
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

HASH_WRITE="${HASH_WRITE:-0}"
HASH_ALGO="${HASH_ALGO:-sha256}"

plugin_parse_opt() {
  case "$1" in
    w) HASH_WRITE=1; export HASH_WRITE; return 0 ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --write) HASH_WRITE=1; AU_CONSUMED=1; export AU_CONSUMED HASH_WRITE; return 0 ;;
    --md5) HASH_ALGO=md5; AU_CONSUMED=1; export AU_CONSUMED HASH_ALGO; return 0 ;;
    --sha256) HASH_ALGO=sha256; AU_CONSUMED=1; export AU_CONSUMED HASH_ALGO; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: hash-verify does not support -d/-D" >&2
    return 1
  fi
  case "$HASH_ALGO" in md5|sha256) ;; *)
    echo "Error: invalid hash algo" >&2; return 1 ;;
  esac
  return 0
}

plugin_require_deps() {
  require_cmds flock
  if [[ "$HASH_ALGO" == md5 ]]; then require_cmds md5sum
  else require_cmds sha256sum; fi
}

plugin_banner_extra() {
  if [[ "${HASH_WRITE:-0}" -eq 1 ]]; then
    log_always "mode:      write .${HASH_ALGO} sidecars"
  else
    log_always "mode:      verify .${HASH_ALGO} sidecars"
  fi
}

plugin_export_env() {
  export HASH_WRITE HASH_ALGO AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
