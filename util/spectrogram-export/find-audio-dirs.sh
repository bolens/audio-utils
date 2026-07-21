#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../../lib/find-audio-dirs.sh" \
  --ext flac -e wav -e aiff -e aif -e mp3 -e opus -e m4a -e ogg -e oga "$@"
