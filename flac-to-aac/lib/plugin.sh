#!/usr/bin/env bash
# flac-to-aac plugin — shared lossy pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-aac}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=m4a
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2aac
AU_SUCCESS_COLUMNS='timestamp,flac,m4a,src_audio_md5,m4a_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

LOSSY_FAMILY=aac
LOSSY_FFMPEG_ENCODER=aac
LOSSY_DEFAULT_QUALITY=192
LOSSY_QUALITY_ENV=AUDIO_UTILS_AAC_QUALITY
LOSSY_QUALITY_ENV_ALT=FLAC2AAC_QUALITY

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

lossy_plugin_wire
