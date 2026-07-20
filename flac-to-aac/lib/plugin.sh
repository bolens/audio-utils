#!/usr/bin/env bash
# flac-to-aac plugin — uses shared lossy pipeline.

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
QUALITY_CLI="${QUALITY_CLI:-}"
LOSSY_NO_RESAMPLE="${LOSSY_NO_RESAMPLE:-0}"

_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_TOOL_DIR=$(cd "${_LIB}/.." && pwd)
_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR \
  LOSSY_FAMILY LOSSY_FFMPEG_ENCODER LOSSY_DEFAULT_QUALITY \
  LOSSY_QUALITY_ENV LOSSY_QUALITY_ENV_ALT
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=../../lib/load.sh
source "${_ROOT}/lib/load.sh"

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
