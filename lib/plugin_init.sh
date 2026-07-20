#!/usr/bin/env bash
# Plugin bootstrap — source from tool/lib/plugin.sh after setting AU_* vars.
#
# Expects to be sourced from <tool>/lib/plugin.sh. Sets AU_TOOL_DIR, sources
# shared lib/load.sh, and exports the standard contract variables.

_AU_CALLER_LIB=$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)
AU_TOOL_DIR=$(cd "${_AU_CALLER_LIB}/.." && pwd)
_AU_ROOT=$(cd "${AU_TOOL_DIR}/.." && pwd)

: "${AU_TOOL_NAME:?AU_TOOL_NAME required before sourcing plugin_init.sh}"
: "${AU_SOURCE_EXT:?AU_SOURCE_EXT required before sourcing plugin_init.sh}"
: "${AU_DEST_EXT:?AU_DEST_EXT required before sourcing plugin_init.sh}"
: "${AU_DISK_FACTOR:?AU_DISK_FACTOR required before sourcing plugin_init.sh}"
: "${AU_WORKDIR_PREFIX:?AU_WORKDIR_PREFIX required before sourcing plugin_init.sh}"
: "${AU_SUCCESS_COLUMNS:?AU_SUCCESS_COLUMNS required before sourcing plugin_init.sh}"

AU_GETOPT_EXTRA="${AU_GETOPT_EXTRA:-}"

export AU_TOOL_NAME AU_SOURCE_EXT AU_DEST_EXT AU_DISK_FACTOR AU_WORKDIR_PREFIX \
  AU_SUCCESS_COLUMNS AU_GETOPT_EXTRA AU_TOOL_DIR
[[ -n "${AU_SOURCE_EXTS:-}" ]] && export AU_SOURCE_EXTS
[[ -n "${AU_SOURCE_LABEL:-}" ]] && export AU_SOURCE_LABEL
[[ -n "${AU_LOSSLESS_CODEC:-}" ]] && export AU_LOSSLESS_CODEC
[[ -n "${AU_CLEANUP_SKIP:-}" ]] && export AU_CLEANUP_SKIP
[[ -n "${AU_TAG_FROM_SOURCE:-}" ]] && export AU_TAG_FROM_SOURCE
[[ -n "${AU_STREAM_TAG:-}" ]] && export AU_STREAM_TAG
[[ -n "${LOSSY_FAMILY:-}" ]] && export LOSSY_FAMILY
[[ -n "${LOSSY_FFMPEG_ENCODER:-}" ]] && export LOSSY_FFMPEG_ENCODER
[[ -n "${LOSSY_DEFAULT_QUALITY:-}" ]] && export LOSSY_DEFAULT_QUALITY
[[ -n "${LOSSY_QUALITY_ENV:-}" ]] && export LOSSY_QUALITY_ENV
[[ -n "${LOSSY_QUALITY_ENV_ALT:-}" ]] && export LOSSY_QUALITY_ENV_ALT

export AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-$AU_WORKDIR_PREFIX}"

# shellcheck source=load.sh
source "${_AU_ROOT}/lib/load.sh"

# Convenience: local modules if present (legacy tools).
for _au_mod in prepare encode convert; do
  if [[ -f "${_AU_CALLER_LIB}/${_au_mod}.sh" ]]; then
    # shellcheck source=/dev/null
    source "${_AU_CALLER_LIB}/${_au_mod}.sh"
  fi
done
unset _au_mod