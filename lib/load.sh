#!/usr/bin/env bash
# Source shared audio-utils library modules (order matters).
# Paths in shellcheck source= directives are relative to this file
# (see sibling tools' .shellcheckrc / root check).
#
# Module layout (see lib/README.md):
#   core/     logging, config, XDG paths, misc plumbing
#   cli/      driver stack (CLI entry, option parsing, workers, discovery)
#   media/    probing, tags, cue/playlist parsing, FLAC helpers
#   pipeline/ conversion pipelines (PCM→FLAC, lossy, disc rips, …)

_AUDIO_UTILS_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- core ---
# shellcheck source=core/log.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/log.sh"
# shellcheck source=core/compat.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/compat.sh"
# shellcheck source=core/xdg.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/xdg.sh"
# shellcheck source=core/config.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/config.sh"
# shellcheck source=core/version.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/version.sh"
# shellcheck source=core/progress.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/progress.sh"
# shellcheck source=core/tmpdir.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/tmpdir.sh"

# --- media ---
# shellcheck source=media/probe.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/probe.sh"
# shellcheck source=media/tags.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/tags.sh"
# shellcheck source=media/audio_exts.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/audio_exts.sh"
# shellcheck source=media/audio_meta.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/audio_meta.sh"

# --- core (needs media/probe) ---
# shellcheck source=core/disk.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/disk.sh"
# shellcheck source=core/util.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/util.sh"
# shellcheck source=core/success_log.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/success_log.sh"
# shellcheck source=core/delete.sh
source "${_AUDIO_UTILS_LIB_DIR}/core/delete.sh"

# --- cli ---
# shellcheck source=cli/convert_all.sh
source "${_AUDIO_UTILS_LIB_DIR}/cli/convert_all.sh"

# --- media / pipeline ---
# shellcheck source=media/pcm_flac.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/pcm_flac.sh"
# shellcheck source=pipeline/pcm_to_flac.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/pcm_to_flac.sh"
# shellcheck source=pipeline/pcm_remux.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/pcm_remux.sh"
# shellcheck source=media/lossless.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/lossless.sh"
# shellcheck source=media/cue.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/cue.sh"
# shellcheck source=media/playlist.sh
source "${_AUDIO_UTILS_LIB_DIR}/media/playlist.sh"
# shellcheck source=pipeline/lossy.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/lossy.sh"
# shellcheck source=pipeline/tak.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/tak.sh"
# shellcheck source=pipeline/ape.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/ape.sh"
# shellcheck source=pipeline/dvd.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/dvd.sh"
# shellcheck source=pipeline/cdda.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/cdda.sh"
# shellcheck source=pipeline/bluray.sh
source "${_AUDIO_UTILS_LIB_DIR}/pipeline/bluray.sh"
