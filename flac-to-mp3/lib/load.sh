#!/usr/bin/env bash
# Source shared audio-utils lib + flac-to-mp3 modules.

_FLAC2MP3_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_AUDIO_UTILS_ROOT=$(cd "${_FLAC2MP3_LIB_DIR}/../.." && pwd)

export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-flac2mp3}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"

# shellcheck source=quality.sh
source "${_FLAC2MP3_LIB_DIR}/quality.sh"
# shellcheck source=success_log.sh
source "${_FLAC2MP3_LIB_DIR}/success_log.sh"
# shellcheck source=encode.sh
source "${_FLAC2MP3_LIB_DIR}/encode.sh"
# shellcheck source=convert.sh
source "${_FLAC2MP3_LIB_DIR}/convert.sh"
# shellcheck source=cleanup.sh
source "${_FLAC2MP3_LIB_DIR}/cleanup.sh"

# Parallel workers inherit MP3_FF_ARGS_STR (arrays cannot be exported).
if [[ -n "${MP3_FF_ARGS_STR:-}" ]]; then
  # shellcheck disable=SC2206
  MP3_FF_ARGS=($MP3_FF_ARGS_STR)
fi
if [[ -z "${MP3_QUALITY_NAME:-}" && -n "${MP3_FF_ARGS_STR:-}" ]]; then
  MP3_QUALITY_NAME=v0
fi
