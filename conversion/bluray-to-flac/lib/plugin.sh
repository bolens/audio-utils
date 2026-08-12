#!/usr/bin/env bash
# bluray-to-flac plugin

AU_TOOL_NAME="${AU_TOOL_NAME:-bluray-to-flac}"
AU_SOURCE_EXT=m2ts
AU_DEST_EXT=flac
AU_DISK_FACTOR=4
AU_WORKDIR_PREFIX=bluray2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

# MakeMKV is checked per input because standalone decrypted media does not need it.
plugin_require_deps() {
  require_cmds flac metaflac ffmpeg ffprobe
}

plugin_export_env() {
  # Note: bluray -D is the BD device path (getopt), not delete-existing.
  export AUDIO_UTILS_BD_DEVICE AUDIO_UTILS_MAKEMKV
  export AUDIO_UTILS_BD_TITLE AUDIO_UTILS_BD_MIN_LENGTH
  export AUDIO_UTILS_BD_DISC_ID
  export AUDIO_UTILS_BD_ALLOW_FLOAT AUDIO_UTILS_BD_STAGE_DIR
  export AUDIO_UTILS_BD_SPLIT_CHAPTERS
  export AUDIO_UTILS_BD_PRESERVE_STREAMS AUDIO_UTILS_BD_SIGN_KEY AUDIO_UTILS_BD_SIGN_PUBKEY
  export AUDIO_UTILS_BD_PAR2_PERCENT AUDIO_UTILS_BD_SEAL
  export AU_CLEANUP_SKIP
}
