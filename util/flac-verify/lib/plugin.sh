#!/usr/bin/env bash
# flac-verify plugin — integrity sweep (read-only).

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-verify}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacverify
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="M"
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

VERIFY_MD5="${VERIFY_MD5:-0}"

plugin_parse_opt() {
  case "$1" in
    M)
      VERIFY_MD5=1
      export VERIFY_MD5
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --md5)
      VERIFY_MD5=1
      AU_CONSUMED=1
      export AU_CONSUMED VERIFY_MD5
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-verify is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: flac-verify is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  if [[ "${VERIFY_MD5:-0}" -eq 1 ]]; then
    require_cmds flac ffmpeg ffprobe flock metaflac
  else
    require_cmds flac flock
  fi
}

plugin_banner_extra() {
  if [[ "${VERIFY_MD5:-0}" -eq 1 ]]; then
    log_always "mode:      flac -t + decode MD5"
  else
    log_always "mode:      flac -t"
  fi
}

plugin_export_env() {
  export VERIFY_MD5 AU_CLEANUP_SKIP
}
