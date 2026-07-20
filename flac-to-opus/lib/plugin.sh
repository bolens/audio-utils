#!/usr/bin/env bash
# flac-to-opus plugin — uses shared lossy pipeline.

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
QUALITY_CLI="${QUALITY_CLI:-}"
LOSSY_NO_RESAMPLE="${LOSSY_NO_RESAMPLE:-0}"

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

lossy_restore_ff_args

convert_one() { lossy_convert_one "$@"; }
plugin_sibling_ok() { lossy_ok "$2"; }

plugin_consume_arg() { lossy_plugin_consume_arg "$@"; }
plugin_parse_opt() { lossy_plugin_parse_opt "$@"; }

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  require_ffmpeg_encoder "$LOSSY_FFMPEG_ENCODER"
}

plugin_after_flags() { lossy_plugin_after_flags; }
plugin_banner_extra() { lossy_plugin_banner; }
plugin_export_env() { lossy_plugin_export_env; }
