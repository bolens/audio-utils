#!/usr/bin/env bash
# Emit VIDEO_TS dirs, BDMV dirs, and dirs that contain .cue sheets.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
ROOTS=()
audio_utils_resolve_roots ROOTS "$@" || exit $?
{
  find_named_dirs VIDEO_TS "${ROOTS[@]}"
  find_named_dirs BDMV "${ROOTS[@]}"
  "${SCRIPT_DIR}/../../lib/find-audio-dirs.sh" --ext cue "${ROOTS[@]}"
} | LC_ALL=C sort -u
