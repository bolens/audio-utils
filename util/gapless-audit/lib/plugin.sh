#!/usr/bin/env bash
# gapless-audit — verify portable lossy files can play back gapless.

AU_TOOL_NAME="${AU_TOOL_NAME:-gapless-audit}"
AU_SOURCE_EXT=mp3
AU_SOURCE_EXTS="mp3 m4a aac"
AU_DEST_EXT=mp3
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=gapaudit
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: gapless-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: gapless-audit is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffprobe flock od dd grep
}

plugin_banner_extra() {
  log_always "mode:      gapless audit (mp3: Xing/Info+LAME; m4a: iTunSMPB)"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
