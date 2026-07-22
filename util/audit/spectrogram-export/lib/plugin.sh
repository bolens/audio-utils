#!/usr/bin/env bash
# spectrogram-export — batch spectrogram PNGs for manual inspection.

AU_TOOL_NAME="${AU_TOOL_NAME:-spectrogram-export}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=png
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=specexp
AU_SUCCESS_COLUMNS='timestamp,file,png,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_VIZ
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

SPECTROGRAM_SIZE="${SPECTROGRAM_SIZE:-1024x512}"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: spectrogram-export does not support -d/-D" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  command -v sox >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  if command -v sox >/dev/null 2>&1; then
    log_always "mode:      spectrograms (sox for PCM/FLAC, ffmpeg otherwise; ${SPECTROGRAM_SIZE})"
  else
    log_always "mode:      spectrograms (ffmpeg showspectrumpic; ${SPECTROGRAM_SIZE})"
  fi
}

plugin_export_env() {
  export SPECTROGRAM_SIZE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
