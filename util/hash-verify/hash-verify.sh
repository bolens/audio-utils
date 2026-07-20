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
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
