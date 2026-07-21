#!/usr/bin/env bash
# flac-cue-export plugin — album dir → image FLAC + CUE.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-cue-export}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=flaccue
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
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

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-cue-export does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac ffmpeg ffprobe flock
}

plugin_banner_extra() {
  log_always "mode:      album dir → image.flac + image.cue"
}

plugin_export_env() {
  if [[ -z "${AU_CUEEXP_STATE:-}" ]]; then
    AU_CUEEXP_STATE=$(audio_utils_mktemp_d "cueexp.XXXXXX")
    register_tmpdir "$AU_CUEEXP_STATE"
  fi
  export AU_CUEEXP_STATE AU_CLEANUP_SKIP
}
