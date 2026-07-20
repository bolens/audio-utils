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
# shellcheck source=tags.sh
source "${_AUDIO_UTILS_LIB_DIR}/tags.sh"
# shellcheck source=audio_meta.sh
source "${_AUDIO_UTILS_LIB_DIR}/audio_meta.sh"
# shellcheck source=disk.sh
source "${_AUDIO_UTILS_LIB_DIR}/disk.sh"
# shellcheck source=util.sh
source "${_AUDIO_UTILS_LIB_DIR}/util.sh"
# shellcheck source=success_log.sh
source "${_AUDIO_UTILS_LIB_DIR}/success_log.sh"
# shellcheck source=delete.sh
source "${_AUDIO_UTILS_LIB_DIR}/delete.sh"
# shellcheck source=convert_all.sh
source "${_AUDIO_UTILS_LIB_DIR}/convert_all.sh"
# shellcheck source=pcm_flac.sh
source "${_AUDIO_UTILS_LIB_DIR}/pcm_flac.sh"
# shellcheck source=pcm_to_flac.sh
source "${_AUDIO_UTILS_LIB_DIR}/pcm_to_flac.sh"
# shellcheck source=pcm_remux.sh
source "${_AUDIO_UTILS_LIB_DIR}/pcm_remux.sh"
# shellcheck source=lossless.sh
source "${_AUDIO_UTILS_LIB_DIR}/lossless.sh"
# shellcheck source=cue.sh
source "${_AUDIO_UTILS_LIB_DIR}/cue.sh"
# shellcheck source=lossy.sh
source "${_AUDIO_UTILS_LIB_DIR}/lossy.sh"
# shellcheck source=tak.sh
source "${_AUDIO_UTILS_LIB_DIR}/tak.sh"
# shellcheck source=dvd.sh
source "${_AUDIO_UTILS_LIB_DIR}/dvd.sh"
# shellcheck source=cdda.sh
source "${_AUDIO_UTILS_LIB_DIR}/cdda.sh"
# shellcheck source=bluray.sh
source "${_AUDIO_UTILS_LIB_DIR}/bluray.sh"
