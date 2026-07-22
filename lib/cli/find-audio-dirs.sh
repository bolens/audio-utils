#!/usr/bin/env bash
# Find subdirectories that contain at least one file matching an extension.
#
# Usage:
#   find-audio-dirs.sh --ext wav [ROOT ...]
#   find-audio-dirs.sh -e aiff -e aif ~/Music
#   find-audio-dirs.sh --preset portable ~/Music
#
# Roots (first match wins):
#   1. Remaining command-line arguments after options
#   2. AUDIO_UTILS_ROOTS (space-separated; WAV2FLAC_ROOTS alias)
#   3. $XDG_CONFIG_HOME/audio-utils/config
#
# Does not follow symlinks (-P). Output sorted with LC_ALL=C.
# Uses GNU find -printf (Linux). Override binary via AUDIO_UTILS_FIND if needed.
#
# Exit codes: 0 ok, 2 usage/config error

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../load.sh
source "${SCRIPT_DIR}/../load.sh"
audio_utils_load_config

EXTS=()
ROOTS=()
FIND_BIN=$(au_find_bin)

usage() {
  cat >&2 <<'EOF'
Usage: find-audio-dirs.sh --ext EXT [-e EXT ...] [ROOT ...]
       find-audio-dirs.sh --preset NAME [ROOT ...]

  --ext EXT, -e EXT   File extension without dot (repeatable; e.g. aiff aif)
  --preset NAME       Shared cluster: portable|portable-pcm|pcm|lossy|
                      portable-pcm-archive|library|library-junk|viz|playlist
                      (see lib/media/audio_exts.sh)
  --version           Print version and exit
  -h, --help          Show this help

Roots via args, AUDIO_UTILS_ROOTS / WAV2FLAC_ROOTS, or
  ${XDG_CONFIG_HOME:-~/.config}/audio-utils/config

Exit codes: 0 ok, 2 usage/config error
EOF
}

_PRESET_HELP="portable|portable-pcm|pcm|lossy|portable-pcm-archive|library|library-junk|viz|playlist"

while (($# > 0)); do
  case "$1" in
    -e|--ext)
      (($# >= 2)) || { echo "Error: $1 needs a value" >&2; exit 2; }
      EXTS+=("$2")
      shift 2
      ;;
    --preset)
      (($# >= 2)) || { echo "Error: --preset needs ${_PRESET_HELP}" >&2; exit 2; }
      _preset_list=$(au_audio_exts_for_preset "$2") || {
        echo "Error: unknown --preset '$2' (${_PRESET_HELP})" >&2
        exit 2
      }
      # shellcheck disable=SC2206
      EXTS+=($_preset_list)
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
  echo "Error: --ext or --preset is required" >&2
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

if ! command -v "$FIND_BIN" >/dev/null 2>&1; then
  echo "Error: find binary not found: $FIND_BIN (set AUDIO_UTILS_FIND or install findutils)" >&2
  exit 2
fi
# Require GNU -printf (BusyBox / BSD find will fail this check).
if ! "$FIND_BIN" . -maxdepth 0 -printf '' >/dev/null 2>&1; then
  echo "Error: $FIND_BIN lacks GNU -printf (need GNU findutils; or set AUDIO_UTILS_FIND)" >&2
  exit 2
fi

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
LC_ALL=C "$FIND_BIN" -P "${ROOTS[@]}" -type f \( "${find_expr[@]}" \) -printf '%h\n' 2>/dev/null \
  | LC_ALL=C sort -u
set -o pipefail
