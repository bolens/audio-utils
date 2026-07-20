#!/usr/bin/env bash
# Source shared audio-utils library modules (order matters).
# Paths in shellcheck source= directives are relative to this file
# (see sibling tools' .shellcheckrc / root check).

_AUDIO_UTILS_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=log.sh
source "${_AUDIO_UTILS_LIB_DIR}/log.sh"
# shellcheck source=xdg.sh
source "${_AUDIO_UTILS_LIB_DIR}/xdg.sh"
# shellcheck source=config.sh
source "${_AUDIO_UTILS_LIB_DIR}/config.sh"
# shellcheck source=version.sh
source "${_AUDIO_UTILS_LIB_DIR}/version.sh"
# shellcheck source=progress.sh
source "${_AUDIO_UTILS_LIB_DIR}/progress.sh"
# shellcheck source=tmpdir.sh
source "${_AUDIO_UTILS_LIB_DIR}/tmpdir.sh"
# shellcheck source=probe.sh
source "${_AUDIO_UTILS_LIB_DIR}/probe.sh"
# shellcheck source=disk.sh
source "${_AUDIO_UTILS_LIB_DIR}/disk.sh"
# shellcheck source=util.sh
source "${_AUDIO_UTILS_LIB_DIR}/util.sh"
# shellcheck source=pcm_flac.sh
source "${_AUDIO_UTILS_LIB_DIR}/pcm_flac.sh"
