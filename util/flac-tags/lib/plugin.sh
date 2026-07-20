#!/usr/bin/env bash
# flac-tags plugin — normalize / fix Vorbis comments.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-tags}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flactags
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="Ak"
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

TAGS_FILL_ALBUMARTIST="${TAGS_FILL_ALBUMARTIST:-0}"
TAGS_KEEP_ENCODER="${TAGS_KEEP_ENCODER:-0}"

plugin_parse_opt() {
  case "$1" in
    A)
      TAGS_FILL_ALBUMARTIST=1
      export TAGS_FILL_ALBUMARTIST
      return 0
      ;;
    k)
      TAGS_KEEP_ENCODER=1
      export TAGS_KEEP_ENCODER
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --fill-albumartist)
      TAGS_FILL_ALBUMARTIST=1
      AU_CONSUMED=1
      export AU_CONSUMED TAGS_FILL_ALBUMARTIST
      return 0
      ;;
    --keep-encoder)
      TAGS_KEEP_ENCODER=1
      AU_CONSUMED=1
      export AU_CONSUMED TAGS_KEEP_ENCODER
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-tags does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac flock
}

plugin_banner_extra() {
  log_always "mode:      normalize tags (track/date/case/junk)"
  if [[ "${TAGS_FILL_ALBUMARTIST:-0}" -eq 1 ]]; then
    log_always "extra:     fill ALBUMARTIST from ARTIST"
  fi
  if [[ "${TAGS_KEEP_ENCODER:-0}" -eq 1 ]]; then
    log_always "extra:     keep ENCODER-like tags"
  fi
}

plugin_export_env() {
  export TAGS_FILL_ALBUMARTIST TAGS_KEEP_ENCODER AU_CLEANUP_SKIP
}
