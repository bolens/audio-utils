#!/usr/bin/env bash
# lossy-to-flac plugin — normalize lossy sources to FLAC (does not restore quality).

AU_TOOL_NAME="${AU_TOOL_NAME:-lossy-to-flac}"
AU_SOURCE_EXT=mp3
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=lossy2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=lossy

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_LOSSY
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { to_flac_convert_one "$@"; }

# Accept common lossy codecs; reject ALAC (use alac-to-flac).
plugin_accept_source() {
  local codec
  codec=$(audio_codec "$1" 2>/dev/null || true)
  case "$codec" in
    mp3|aac|opus|vorbis|speex|wmav1|wmav2|wmapro|wmalossless|mpc7|mpc8|musepack7|musepack8)
      return 0
      ;;
    alac|"")
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

plugin_export_env() { export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE" AU_SOURCE_LABEL; }
