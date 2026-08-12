#!/usr/bin/env bash
# Safely remove one tool's disposable work directories below configured roots.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/core/util.sh
source "$ROOT/lib/core/util.sh"

if [[ $# -ne 1 || -z "$1" || "$1" == */* ]]; then
  echo "usage: clean-tool-tmp.sh WORKDIR_NAME_GLOB" >&2
  exit 2
fi

declare -a roots=()
audio_utils_roots_from_env roots || {
  echo "Error: set AUDIO_UTILS_ROOTS_FILE, AUDIO_UTILS_ROOTS, or ROOTS=" >&2
  exit 1
}

root=""
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || {
    echo "Error: library root is not a directory: $root" >&2
    exit 1
  }
done

for root in "${roots[@]}"; do
  find -P -- "$root" -type d -name "$1" -print0
done | xargs -0 -r rm -rf --

echo "done"
