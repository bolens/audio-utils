#!/usr/bin/env bash
# Find subdirectories that contain at least one .wav file.
# Thin wrapper around ../lib/find-audio-dirs.sh --ext wav
#
# Roots (first match wins):
#   1. Command-line arguments
#   2. AUDIO_UTILS_ROOTS / WAV2FLAC_ROOTS
#   3. ${XDG_CONFIG_HOME:-~/.config}/audio-utils/config
#
# Examples:
#   ./find-wav-dirs.sh ~/Music ~/Downloads
#   ./find-wav-dirs.sh --version

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../lib/find-audio-dirs.sh" --ext wav "$@"
