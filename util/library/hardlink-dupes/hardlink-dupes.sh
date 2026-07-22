#!/usr/bin/env bash
# hardlink-dupes - hardlink content-identical FLACs to reclaim space.
#
# Usage:
#   hardlink-dupes.sh DIR [DIR ...]
#   find-flac-dirs.sh | hardlink-dupes.sh
#
# Options:
#   --apply       Replace duplicates with hardlinks to the first keeper
#   -M / --md5    Use decode audio MD5 instead of STREAMINFO MD5
#   --cross-fs    Attempt link even across filesystems (usually fails)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Report-only by default (exit 1 when candidates exist). Does not support -d/-D/-y.
# Prefer flac-dupes for discovery-only; this tool optionally reclaims inodes.
# Exit codes: 0 ok, 1 candidates/failures, 2 usage/deps

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
