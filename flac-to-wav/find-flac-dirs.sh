#!/usr/bin/env bash
# Find subdirectories that contain at least one .flac file.
# Thin wrapper around ../lib/find-audio-dirs.sh --ext flac

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../lib/find-audio-dirs.sh" --ext flac "$@"
