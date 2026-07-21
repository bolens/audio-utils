#!/usr/bin/env bash
# Verify or write sidecar checksums (.sha256 / .md5) for audio files.
#
# Usage:
#   hash-verify.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -w / --write   Write sidecars (default: verify existing)
#   --sha256       Use SHA-256 (default)
#   --md5          Use MD5
#
# -d / -D rejected.
# Exit codes: 0 ok, 1 mismatches/missing, 2 usage/deps

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
