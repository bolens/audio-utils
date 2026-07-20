#!/usr/bin/env bash
# Find dirs with lossy audio and convert. Extra args go to lossy-to-flac.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-lossy-dirs.sh" \
  "${SCRIPT_DIR}/lossy-to-flac.sh" \
  "lossy" \
  "$@"
