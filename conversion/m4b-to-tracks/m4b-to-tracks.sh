#!/usr/bin/env bash
# m4b-to-tracks - one .m4b → per-chapter files.
#
# Usage:
#   m4b-to-tracks.sh DIR [DIR ...]
#   find-m4b-dirs.sh | m4b-to-tracks.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#
# -d / -D rejected (source .m4b kept). Writes <stem>/NN - Title.m4a beside the book.
# Fails when the .m4b has no chapters.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
