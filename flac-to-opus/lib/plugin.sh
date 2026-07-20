#!/usr/bin/env bash
# flac-to-opus plugin — shared lossy pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-opus}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=opus
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2opus
AU_SUCCESS_COLUMNS='timestamp,flac,opus,src_audio_md5,opus_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

LOSSY_FAMILY=opus
LOSSY_FFMPEG_ENCODER=libopus
LOSSY_DEFAULT_QUALITY=128
LOSSY_QUALITY_ENV=AUDIO_UTILS_OPUS_QUALITY
LOSSY_QUALITY_ENV_ALT=FLAC2OPUS_QUALITY

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

lossy_plugin_wire
# shellcheck source=../../lib/lossy_hooks.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/lossy_hooks.sh"
