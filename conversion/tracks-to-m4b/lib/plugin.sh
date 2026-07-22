#!/usr/bin/env bash
# tracks-to-m4b — chapter files in a directory → one .m4b.

AU_TOOL_NAME="${AU_TOOL_NAME:-tracks-to-m4b}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=m4b
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=tracks2m4b
AU_SUCCESS_COLUMNS='timestamp,dir,m4b,src_audio_md5,m4b_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$(au_audio_exts_for_preset portable-pcm)
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

M4B_CODEC="${M4B_CODEC:-${AUDIO_UTILS_M4B_CODEC:-aac}}"
M4B_QUALITY="${M4B_QUALITY:-${AUDIO_UTILS_M4B_QUALITY:-96}}"

plugin_consume_arg() {
  case "${1:-}" in
    --codec=*)
      M4B_CODEC=${1#--codec=}
      AU_CONSUMED=1
      export AU_CONSUMED M4B_CODEC
      return 0
      ;;
    --codec)
      M4B_CODEC="${2:-}"
      AU_CONSUMED=2
      export AU_CONSUMED M4B_CODEC
      return 0
      ;;
    --quality=*)
      M4B_QUALITY=${1#--quality=}
      AU_CONSUMED=1
      export AU_CONSUMED M4B_QUALITY
      return 0
      ;;
    --quality)
      M4B_QUALITY="${2:-}"
      AU_CONSUMED=2
      export AU_CONSUMED M4B_QUALITY
      return 0
      ;;
  esac
  return 1
}

plugin_parse_opt() {
  case "$1" in
    Q)
      M4B_QUALITY=$OPTARG
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  case "${M4B_CODEC,,}" in
    aac|opus|alac) M4B_CODEC=${M4B_CODEC,,} ;;
    *)
      echo "Error: --codec must be aac, opus, or alac (got: $M4B_CODEC)" >&2
      return 1
      ;;
  esac
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: tracks-to-m4b does not support -d/-D (chapter sources kept)" >&2
    return 1
  fi
  export M4B_CODEC M4B_QUALITY
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  case "${M4B_CODEC:-aac}" in
    opus) require_ffmpeg_encoder libopus || return 1 ;;
  esac
}

plugin_banner_extra() {
  log_always "mode:      tracks -> m4b (codec=$M4B_CODEC quality=$M4B_QUALITY)"
}

plugin_export_env() {
  if [[ -z "${AU_M4B_STATE:-}" ]]; then
    AU_M4B_STATE=$(audio_utils_mktemp_d "tracks2m4b.XXXXXX")
    register_tmpdir "$AU_M4B_STATE"
  fi
  export AU_M4B_STATE M4B_CODEC M4B_QUALITY AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
