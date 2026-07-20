#!/usr/bin/env bash
# playlist-generate — build .m3u playlists from audio directories.

AU_TOOL_NAME="${AU_TOOL_NAME:-playlist-generate}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc aac wav aiff aif caf wv ape tak tta"
AU_DEST_EXT=m3u
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=plgen
AU_SUCCESS_COLUMNS='timestamp,dir,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: playlist-generate does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flock
  command -v ffprobe >/dev/null 2>&1 || true
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_accept_source() {
  local f=$1 base
  base=$(basename -- "$f")
  case "${base,,}" in
    *.flac|*.mp3|*.opus|*.m4a|*.ogg|*.oga|*.wma|*.mpc|*.aac|*.wav|*.aiff|*.aif|*.caf|*.wv|*.ape|*.tak|*.tta)
      return 0
      ;;
    *) return 1 ;;
  esac
}

plugin_banner_extra() {
  log_always "mode:      generate .m3u per audio directory (relative paths)"
}

plugin_export_env() {
  if [[ -z "${AU_PLGEN_STATE:-}" ]]; then
    AU_PLGEN_STATE=$(audio_utils_mktemp_d "plgen.XXXXXX")
    register_tmpdir "$AU_PLGEN_STATE"
  fi
  export AU_PLGEN_STATE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
