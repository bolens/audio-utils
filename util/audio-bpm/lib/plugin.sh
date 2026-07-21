#!/usr/bin/env bash
# audio-bpm — detect tempo, save as BPM tag (multi-format).

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-bpm}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc aac"
AU_DEST_EXT=flac
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=audiobpm
AU_SUCCESS_COLUMNS='timestamp,file,mode,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_CLEANUP_SKIP=1

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

BPM_BACKEND="${BPM_BACKEND:-}"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-bpm does not support -d/-D" >&2
    return 1
  fi
  if command -v bpm >/dev/null 2>&1; then
    BPM_BACKEND=bpm
  elif command -v aubio >/dev/null 2>&1; then
    BPM_BACKEND=aubio
  else
    echo "Error: need bpm (bpm-tools, preferred) or aubio in PATH" >&2
    return 1
  fi
  export BPM_BACKEND
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock awk
  require_cmds "$BPM_BACKEND"
  command -v metaflac >/dev/null 2>&1 || true
  return 0
}

plugin_banner_extra() {
  log_always "mode:      tag BPM (${BPM_BACKEND})"
}

plugin_export_env() {
  export BPM_BACKEND AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
