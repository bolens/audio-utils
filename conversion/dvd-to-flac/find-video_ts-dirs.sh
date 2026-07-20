#!/usr/bin/env bash
# List VIDEO_TS directories under roots.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
ROOTS=()
audio_utils_resolve_roots ROOTS "$@" || exit $?
find_named_dirs VIDEO_TS "${ROOTS[@]}"
