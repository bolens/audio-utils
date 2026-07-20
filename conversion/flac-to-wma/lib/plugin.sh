#!/usr/bin/env bash
# flac-to-wma plugin — shared lossy pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-wma}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=wma
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2wma
AU_SUCCESS_COLUMNS='timestamp,flac,wma,src_audio_md5,wma_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

LOSSY_FAMILY=wma
LOSSY_FFMPEG_ENCODER=wmav2
LOSSY_DEFAULT_QUALITY=192
LOSSY_QUALITY_ENV=AUDIO_UTILS_WMA_QUALITY
LOSSY_QUALITY_ENV_ALT=FLAC2WMA_QUALITY

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

lossy_plugin_wire
# shellcheck source=../../../lib/lossy_hooks.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/lossy_hooks.sh"
