#!/usr/bin/env bash
# Safely remove one tool's disposable work directories below configured roots.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/core/util.sh
source "$ROOT/lib/core/util.sh"

if [[ $# -ne 1 || ! "$1" =~ ^\.[A-Za-z0-9][A-Za-z0-9._-]*\.\*$ ]]; then
  echo "usage: clean-tool-tmp.sh WORKDIR_NAME_GLOB" >&2
  exit 2
fi
prefix=${1%.\*}

declare -a roots=()
if [[ -n "${AUDIO_UTILS_CLEAN_ROOTS+x}" ]]; then
  [[ -n "$AUDIO_UTILS_CLEAN_ROOTS" ]] || {
    echo "Error: set AUDIO_UTILS_ROOTS_FILE, AUDIO_UTILS_ROOTS, or ROOTS=" >&2
    exit 1
  }
  roots=("$AUDIO_UTILS_CLEAN_ROOTS")
fi
if ((${#roots[@]} == 0)) && ! audio_utils_roots_from_env roots; then
  echo "Error: set AUDIO_UTILS_ROOTS_FILE, AUDIO_UTILS_ROOTS, or ROOTS=" >&2
  exit 1
fi

root=""
for root in "${roots[@]}"; do
  [[ -d "$root" ]] || {
    echo "Error: library root is not a directory: $root" >&2
    exit 1
  }
done

matches=$(mktemp "${TMPDIR:-/tmp}/audio-utils-clean.XXXXXX") || exit 1
trap 'rm -f -- "$matches"' EXIT
for root in "${roots[@]}"; do
  while IFS= read -r -d '' match; do
    suffix=${match##*/}
    suffix=${suffix#"${prefix}."}
    [[ "$suffix" =~ ^[A-Za-z0-9]{6}$ ]] || continue
    printf '%s\0' "$match" >>"$matches"
  done < <(find -P -- "$root" -mindepth 1 -type d -name "${prefix}.*" -print0)
done

while IFS= read -r -d '' match; do
  for root in "${roots[@]}"; do
    [[ "$match" != "$root" ]] || {
      echo "Error: refusing to remove library root: $root" >&2
      exit 1
    }
  done
  rm -rf -- "$match"
done <"$matches"

echo "done"
