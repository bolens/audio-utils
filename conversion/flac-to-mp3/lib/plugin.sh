#!/usr/bin/env bash
# flac-to-mp3 plugin — shared lossy pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-mp3}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=mp3
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2mp3
AU_SUCCESS_COLUMNS='timestamp,flac,mp3,src_audio_md5,mp3_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

LOSSY_FAMILY=mp3
LOSSY_FFMPEG_ENCODER=libmp3lame
LOSSY_DEFAULT_QUALITY=v0
LOSSY_QUALITY_ENV=AUDIO_UTILS_MP3_QUALITY
LOSSY_QUALITY_ENV_ALT=FLAC2MP3_QUALITY

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

lossy_plugin_wire
# shellcheck source=../../../lib/pipeline/lossy_hooks.sh
source "$_AU_ROOT/lib/pipeline/lossy_hooks.sh"
