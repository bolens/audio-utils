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

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

lossy_plugin_wire
