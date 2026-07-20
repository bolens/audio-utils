#!/usr/bin/env bash
# Find dirs with AIFF/AIF files.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../lib/find-audio-dirs.sh" -e aiff -e aif "$@"
