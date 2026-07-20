#!/usr/bin/env bash
# Find content duplicates across FLAC and lossy formats.
#
# Usage:
#   audio-dupes.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --fingerprint   Chromaprint (default)
#   -M / --md5      Decode audio MD5 instead
#
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 no dupes, 1 dupes/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
