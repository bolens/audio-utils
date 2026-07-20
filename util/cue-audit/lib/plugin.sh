#!/usr/bin/env bash
# cue-audit — validate CUE sheets and referenced images.

AU_TOOL_NAME="${AU_TOOL_NAME:-cue-audit}"
AU_SOURCE_EXT=cue
AU_DEST_EXT=cue
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=cueaudit
AU_SUCCESS_COLUMNS='timestamp,cue,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: cue-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: cue-audit is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flock
  command -v iconv >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  log_always "mode:      cue audit (image, tracks, utf-8)"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP
}
