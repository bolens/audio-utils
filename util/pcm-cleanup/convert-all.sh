#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-pcm-dirs.sh" \
  "${SCRIPT_DIR}/pcm-cleanup.sh" \
  "PCM" \
  "$@"
