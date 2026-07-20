#!/usr/bin/env bash
# Find subdirectories that contain at least one file matching an extension.
#
# Usage:
#   find-audio-dirs.sh --ext wav [ROOT ...]
#   find-audio-dirs.sh -e aiff -e aif ~/Music
#
# Roots (first match wins):
#   1. Remaining command-line arguments after --ext
#   2. AUDIO_UTILS_ROOTS (space-separated; WAV2FLAC_ROOTS alias)
#   3. $XDG_CONFIG_HOME/audio-utils/config
#
# Does not follow symlinks (-P). Output sorted with LC_ALL=C.
# Note: uses GNU find -printf (Linux). On macOS: brew install findutils && use gfind.
#
# Exit codes: 0 ok, 2 usage/config error

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=load.sh
source "${SCRIPT_DIR}/load.sh"
audio_utils_load_config

EXTS=()
ROOTS=()

usage() {
  cat >&2 <<'EOF'
Usage: find-audio-dirs.sh --ext EXT [-e EXT ...] [ROOT ...]

  --ext EXT, -e EXT   File extension without dot (repeatable; e.g. aiff aif)
  --version           Print version and exit
  -h, --help          Show this help

Roots via args, AUDIO_UTILS_ROOTS / WAV2FLAC_ROOTS, or
  ${XDG_CONFIG_HOME:-~/.config}/audio-utils/config

Exit codes: 0 ok, 2 usage/config error
EOF
}

while (($# > 0)); do
  case "$1" in
    -e|--ext)
      (($# >= 2)) || { echo "Error: $1 needs a value" >&2; exit 2; }
      EXTS+=("$2")
      shift 2
      ;;
    --version)
      audio_utils_print_version "find-audio-dirs"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      ROOTS+=("$@")
      break
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      ROOTS+=("$1")
      shift
      ;;
  esac
done

if ((${#EXTS[@]} == 0)); then
  echo "Error: --ext is required" >&2
  usage
  exit 2
fi

# Normalize: strip dots, lower-case
_norm=()
for _e in "${EXTS[@]}"; do
  _e="${_e#.}"
  _e="${_e,,}"
  _norm+=("$_e")
done
EXTS=("${_norm[@]}")

if ((${#ROOTS[@]} == 0)); then
  raw="${AUDIO_UTILS_ROOTS:-${WAV2FLAC_ROOTS:-}}"
  if [[ -z "$raw" ]]; then
    cat >&2 <<EOF
Error: no search roots given.

Pass directories as arguments, set AUDIO_UTILS_ROOTS, or add to
  $(audio_utils_config_path)

  find-audio-dirs.sh --ext wav ~/Music ~/Downloads
  AUDIO_UTILS_ROOTS="\$HOME/Music" find-audio-dirs.sh --ext wav

EOF
    exit 2
  fi
  # shellcheck disable=SC2206
  ROOTS=($raw)
fi

missing_count=0
for root in "${ROOTS[@]}"; do
  if [[ ! -d "$root" ]]; then
    echo "Error: directory not found: $root" >&2
    ((missing_count++)) || true
  fi
done
((missing_count == 0)) || exit 2

find_expr=()
_first=1
for _e in "${EXTS[@]}"; do
  if ((_first)); then
    find_expr=( -iname "*.${_e}" )
    _first=0
  else
    find_expr+=( -o -iname "*.${_e}" )
  fi
done

# List unique parent dirs of every matching file, sorted (C locale).
set +o pipefail
LC_ALL=C find -P "${ROOTS[@]}" -type f \( "${find_expr[@]}" \) -printf '%h\n' 2>/dev/null \
  | LC_ALL=C sort -u
set -o pipefail
