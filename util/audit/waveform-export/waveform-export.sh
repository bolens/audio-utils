#!/usr/bin/env bash
# waveform-export — batch waveform PNGs beside each audio file.
#
# Usage:
#   waveform-export.sh DIR [DIR ...]
#   find-audio-dirs.sh | waveform-export.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#
# Writes <file>.waveform.png (WAVEFORM_SIZE default 1920x240).
# Sibling to spectrogram-export.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
