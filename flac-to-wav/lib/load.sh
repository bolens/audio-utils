#!/usr/bin/env bash
# Source shared audio-utils lib + flac-to-wav modules.

_FLAC2WAV_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_AUDIO_UTILS_ROOT=$(cd "${_FLAC2WAV_LIB_DIR}/../.." && pwd)

export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-flac2wav}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"

# shellcheck source=success_log.sh
source "${_FLAC2WAV_LIB_DIR}/success_log.sh"
# shellcheck source=encode.sh
source "${_FLAC2WAV_LIB_DIR}/encode.sh"
# shellcheck source=convert.sh
source "${_FLAC2WAV_LIB_DIR}/convert.sh"
# shellcheck source=cleanup.sh
source "${_FLAC2WAV_LIB_DIR}/cleanup.sh"
