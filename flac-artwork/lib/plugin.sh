#!/usr/bin/env bash
# flac-artwork plugin — embed or extract cover art.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-artwork}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacart
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="x"
AU_CLEANUP_SKIP=1

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

ART_EXTRACT="${ART_EXTRACT:-0}"

plugin_parse_opt() {
  case "$1" in
    x)
      ART_EXTRACT=1
      export ART_EXTRACT
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --extract)
      ART_EXTRACT=1
      AU_CONSUMED=1
      export AU_CONSUMED ART_EXTRACT
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-artwork does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac flock
}

plugin_banner_extra() {
  if [[ "${ART_EXTRACT:-0}" -eq 1 ]]; then
    log_always "mode:      extract → cover.jpg"
  else
    log_always "mode:      embed from folder cover"
  fi
}

plugin_export_env() {
  export ART_EXTRACT AU_CLEANUP_SKIP
}
