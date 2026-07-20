#!/usr/bin/env bash
# Normalize FLAC Vorbis comments under library roots.
#
# Usage:
#   flac-tags.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-tags.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -A / --fill-albumartist   Set ALBUMARTIST from ARTIST when missing
#   -k / --keep-encoder       Keep ENCODER/TOOL/RIPPER-like tags
#
# Normalizes: uppercase keys, trim values, TRACKNUMBER zero-pad, DATE,
# strip iTunes/encoder junk. -y rewrites even when already clean.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=16
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
