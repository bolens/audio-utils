#!/usr/bin/env bash
# lossy-authenticity — detect re-encoded / fake high-bitrate lossy audio.

AU_TOOL_NAME="${AU_TOOL_NAME:-lossy-authenticity}"
AU_SOURCE_EXT=mp3
AU_DEST_EXT=mp3
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=lossyauth
AU_SUCCESS_COLUMNS='timestamp,file,verdict,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="s"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_LOSSY
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

LOSSYAUTH_STRICT="${LOSSYAUTH_STRICT:-0}"

plugin_parse_opt() {
  case "$1" in
    s)
      LOSSYAUTH_STRICT=1
      export LOSSYAUTH_STRICT
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --strict)
      LOSSYAUTH_STRICT=1
      AU_CONSUMED=1
      export AU_CONSUMED LOSSYAUTH_STRICT
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: lossy-authenticity is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: lossy-authenticity is read-only; -y is not supported" >&2
    return 1
  fi
  export LOSSYAUTH_STRICT
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock awk
}

plugin_banner_extra() {
  if [[ "${LOSSYAUTH_STRICT:-0}" -eq 1 ]]; then
    log_always "mode:      lossy authenticity (strict spectral cliff)"
  else
    log_always "mode:      lossy authenticity (spectral cliff vs bitrate)"
  fi
}

plugin_export_env() {
  export LOSSYAUTH_STRICT AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
