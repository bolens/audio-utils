#!/usr/bin/env bash
# waveform-export — batch waveform PNGs for visual QC.

AU_TOOL_NAME="${AU_TOOL_NAME:-waveform-export}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac wav aiff aif caf mp3 opus m4a ogg oga"
AU_DEST_EXT=png
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=waveexp
AU_SUCCESS_COLUMNS='timestamp,file,png,audio_md5,file_sha256,codec,bytes,samples,notes'
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

WAVEFORM_SIZE="${WAVEFORM_SIZE:-1920x240}"
WAVEFORM_COLORS="${WAVEFORM_COLORS:-white|gray}"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: waveform-export does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
}

plugin_banner_extra() {
  log_always "mode:      waveforms (ffmpeg showwavespic; ${WAVEFORM_SIZE})"
}

plugin_export_env() {
  export WAVEFORM_SIZE WAVEFORM_COLORS AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
