#!/usr/bin/env bash
# m4b-to-tracks — one .m4b → per-chapter files.

AU_TOOL_NAME="${AU_TOOL_NAME:-m4b-to-tracks}"
AU_SOURCE_EXT=m4b
AU_DEST_EXT=m4a
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=m4b2tracks
AU_SUCCESS_COLUMNS='timestamp,m4b,track,audio_md5,track_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: m4b-to-tracks does not support -d/-D (source .m4b is kept)" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_banner_extra() {
  log_always "mode:      m4b -> chapter tracks (stream copy when possible)"
}

plugin_export_env() {
  export AU_CLEANUP_SKIP
}
