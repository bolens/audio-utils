#!/usr/bin/env bash
# Source shared audio-utils lib + wav-to-flac modules (order matters).
# See ../.shellcheckrc for source-path (SCRIPTDIR, lib, ../../lib).

_WAV2FLAC_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_AUDIO_UTILS_ROOT=$(cd "${_WAV2FLAC_LIB_DIR}/../.." && pwd)

# Workdirs stay `.wav2flac.*` for orphan sweep compatibility with prior runs.
export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-wav2flac}"

# shellcheck source=../../lib/load.sh
source "${_AUDIO_UTILS_ROOT}/lib/load.sh"

# shellcheck source=success_log.sh
source "${_WAV2FLAC_LIB_DIR}/success_log.sh"
# shellcheck source=prepare.sh
source "${_WAV2FLAC_LIB_DIR}/prepare.sh"
# shellcheck source=encode.sh
source "${_WAV2FLAC_LIB_DIR}/encode.sh"
# shellcheck source=convert.sh
source "${_WAV2FLAC_LIB_DIR}/convert.sh"
# shellcheck source=cleanup.sh
source "${_WAV2FLAC_LIB_DIR}/cleanup.sh"
