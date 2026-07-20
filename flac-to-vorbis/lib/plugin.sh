#!/usr/bin/env bash
# flac-to-vorbis plugin — shared lossy pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-vorbis}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=ogg
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2vorbis
AU_SUCCESS_COLUMNS='timestamp,flac,ogg,src_audio_md5,ogg_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

LOSSY_FAMILY=vorbis
LOSSY_FFMPEG_ENCODER=libvorbis
LOSSY_DEFAULT_QUALITY=q6
LOSSY_QUALITY_ENV=AUDIO_UTILS_VORBIS_QUALITY
LOSSY_QUALITY_ENV_ALT=FLAC2VORBIS_QUALITY

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

lossy_plugin_wire
# shellcheck source=../../lib/lossy_hooks.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/lossy_hooks.sh"
