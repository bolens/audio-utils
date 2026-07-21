#!/usr/bin/env bash
# Rename FLACs from tags (inplace or Artist/Album layout).
#
# Usage:
#   flac-rename.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-rename.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   --layout=inplace|artist-album   Default: inplace (NN - Title.flac)
#   --dest-root=DIR                 Required for artist-album (or AUDIO_UTILS_ROOTS)
#
# Target name: NN - Title.flac from TRACKNUMBER + TITLE.
# artist-album: DEST/Artist/Album/NN - Title.flac
# -d / -D rejected. -y overwrites an existing target.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=16
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
