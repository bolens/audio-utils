#!/usr/bin/env bash
# flac-optimize plugin — recompress FLAC without changing audio.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-optimize}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=flacopt
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="c:"
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

OPT_LEVEL="${OPT_LEVEL:-8}"

plugin_parse_opt() {
  case "$1" in
    c)
      OPT_LEVEL=$2
      export OPT_LEVEL
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --compression=*)
      OPT_LEVEL="${1#--compression=}"
      AU_CONSUMED=1
      export AU_CONSUMED OPT_LEVEL
      return 0
      ;;
    --compression)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --compression requires 0-8" >&2
        return 1
      fi
      OPT_LEVEL=$2
      AU_CONSUMED=2
      export AU_CONSUMED OPT_LEVEL
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-optimize does not support -d/-D" >&2
    return 1
  fi
  if [[ ! "$OPT_LEVEL" =~ ^[0-8]$ ]]; then
    echo "Error: compression level must be 0-8 (got: $OPT_LEVEL)" >&2
    return 1
  fi
  export OPT_LEVEL
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac ffmpeg ffprobe flock
}

plugin_banner_extra() {
  log_always "mode:      recompress flac -$OPT_LEVEL (bit-identical PCM)"
}

plugin_export_env() {
  export OPT_LEVEL AU_CLEANUP_SKIP
}
