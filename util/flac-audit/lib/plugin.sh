#!/usr/bin/env bash
# flac-audit plugin — read-only library health report.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-audit}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacaudit
AU_SUCCESS_COLUMNS='timestamp,flac,status,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: flac-audit is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac flock
}

plugin_banner_extra() {
  log_always "mode:      audit (integrity, tags, cover, leftover PCM)"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP
}
