#!/usr/bin/env bash
# Convert FLAC files to WAV in one or more directories, with verification.
#
# Verification (per file):
#   1. flac -t on source
#   2. Dual decode to bit-depth-matched PCM; audio MD5 == FLAC audio MD5
#   3. Copy tags/cover from FLAC; audio MD5 unchanged
# Existing WAVs that probe OK are skipped; corrupt siblings are reconverted.
# Temps beside destination (atomic mv); cleaned on EXIT/INT/TERM.
#
# Usage:
#   flac-to-wav.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-to-wav.sh
#   convert-all.sh [options...]
#
# Options:
#   -f FILE     Read directory list from FILE
#   -d          Delete FLAC after successful conversion
#   -D          Cleanup only: delete FLACs that already have a valid sibling WAV
#   -L FILE     Failure log (default: $XDG_STATE_HOME/audio-utils/flac-to-wav/failures.log)
#   -S FILE     Success log CSV or .jsonl
#   -n          Dry run
#   -y          Overwrite existing WAVs even if probe passes
#   -j N        Parallel jobs (default: max(1, nproc/2))
#   -q          Quiet
#   -v          Verbose
#   -h          Help
#   --version   Print version
#
# Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=30
# shellcheck source=../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/cli.sh"
audio_utils_cli_run "$@"
