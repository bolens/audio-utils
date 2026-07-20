#!/usr/bin/env bash
# Find FLAC dirs and verify. Extra args are passed to flac-verify.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-flac-dirs.sh" \
  "${SCRIPT_DIR}/flac-verify.sh" \
  "FLAC" \
  "$@"
