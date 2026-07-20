#!/usr/bin/env bash
# lossy-to-flac plugin — normalize lossy sources to FLAC (does not restore quality).

AU_TOOL_NAME="${AU_TOOL_NAME:-lossy-to-flac}"
AU_SOURCE_EXT=mp3
AU_SOURCE_EXTS="mp3 m4a aac opus ogg wma mpc"
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=lossy2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=lossy

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { to_flac_convert_one "$@"; }

# Accept common lossy codecs; reject ALAC (use alac-to-flac).
plugin_accept_source() {
  local codec
  codec=$(audio_codec "$1" 2>/dev/null || true)
  case "$codec" in
    mp3|aac|opus|vorbis|wmav1|wmav2|wmapro|wmalossless|mpc7|mpc8|musepack7|musepack8)
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
