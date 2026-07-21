#!/usr/bin/env bash
# Materialize playlists onto a device: copy referenced files + rewritten .m3u.
#
# Usage:
#   playlist-export.sh --dest DIR PLAYLIST_DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --dest=DIR      Destination root (required); one subdirectory per playlist
#   --number        Prefix copied files with a 3-digit play order
#   -y              Overwrite existing files at the destination
#
# -d / -D rejected. Existing same-size destination files are skipped.
# Exit codes: 0 ok, 1 failures/missing entries, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
