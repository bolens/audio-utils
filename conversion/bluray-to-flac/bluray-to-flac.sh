#!/usr/bin/env bash
# Extract Blu-ray / BDMV / decrypted M2TS|MKV audio -> FLAC.
#
# Usage:
#   bluray-to-flac.sh /path/to/BDMV [/path/to/disc ...]
#   bluray-to-flac.sh /path/to/decrypted.m2ts
#   bluray-to-flac.sh -D /dev/sr0
#   find-bdmv-dirs.sh | bluray-to-flac.sh
#
# Options:
#   -D DEVICE  Blu-ray device
#   --title N|all       MakeMKV title selection (default: all)
#   --minlength SEC     Ignore shorter MakeMKV titles (default: 0 keeps all)
#   --allow-float-reduction  Permit verified float PCM -> 24-bit conversion
#   --split-chapters    Also create verified per-chapter FLAC tracks
#   --stage-dir DIR     Keep/reuse MakeMKV title MKVs under DIR
#   --verify-archive DIR  Verify DIR/SHA256SUMS and exit
#   --audit-archive DIR   Verify checksums, FLACs, MD5s, signatures, PAR2
#   --preserve-streams    Keep original codec bitstreams as .source.mka
#   --sign-key FILE       Sign SHA256SUMS with minisign
#   --par2-percent N      Generate N percent PAR2 recovery data
#   --seal                Sync and make archive metadata read-only
#   -f FILE  -L FILE  -S FILE  --dirs0  -n  -y  -q  -v  -h  --version
#   -j N       Accepted for CLI parity; extract is serial per title (ignored)
#
# MakeMKV resolves authored BDMV/device titles; standalone decrypted media is
# accepted directly. Raw STREAM clips are not interpreted as titles.
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"

audio_utils_load_config

DIR_FILE=""
DIRS0=0
DRY_RUN=0
OVERWRITE=0
QUIET=0
VERBOSE=0
FAIL_LOG=""
SUCCESS_LOG=""
DELETE_SOURCE=0
BD_DEVICE="${AUDIO_UTILS_BD_DEVICE:-}"
AUDIO_UTILS_BD_TITLE="${AUDIO_UTILS_BD_TITLE:-all}"
AUDIO_UTILS_BD_MIN_LENGTH="${AUDIO_UTILS_BD_MIN_LENGTH:-0}"
AUDIO_UTILS_BD_ALLOW_FLOAT="${AUDIO_UTILS_BD_ALLOW_FLOAT:-0}"
AUDIO_UTILS_BD_STAGE_DIR="${AUDIO_UTILS_BD_STAGE_DIR:-}"
AUDIO_UTILS_BD_SPLIT_CHAPTERS="${AUDIO_UTILS_BD_SPLIT_CHAPTERS:-0}"
VERIFY_ARCHIVE=""
AUDIT_ARCHIVE=""
AUDIO_UTILS_BD_PRESERVE_STREAMS="${AUDIO_UTILS_BD_PRESERVE_STREAMS:-0}"
AUDIO_UTILS_BD_SIGN_KEY="${AUDIO_UTILS_BD_SIGN_KEY:-}"
AUDIO_UTILS_BD_SIGN_PUBKEY="${AUDIO_UTILS_BD_SIGN_PUBKEY:-}"
AUDIO_UTILS_BD_PAR2_PERCENT="${AUDIO_UTILS_BD_PAR2_PERCENT:-0}"
AUDIO_UTILS_BD_SEAL="${AUDIO_UTILS_BD_SEAL:-0}"

usage() {
  sed -n '2,/^# Exit codes:/p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (($# > 0)); do
  case "$1" in
    -D)
      [[ $# -ge 2 ]] || { echo "Error: -D needs a device" >&2; usage 2; }
      BD_DEVICE=$2
      shift 2
      ;;
    -f|-L|-S|-j)
      [[ $# -ge 2 ]] || { echo "Error: $1 needs a value" >&2; usage 2; }
      case "$1" in
        -f) DIR_FILE=$2 ;;
        -L) FAIL_LOG=$2 ;;
        -S) SUCCESS_LOG=$2 ;;
        -j)
          [[ $2 =~ ^[1-9][0-9]*$ ]] || {
            echo "Error: -j needs a positive integer" >&2
            usage 2
          }
          ;;
      esac
      shift 2
      ;;
    --dirs0) DIRS0=1; shift ;;
    --title)
      [[ $# -ge 2 && ( "$2" == all || "$2" =~ ^[0-9]+$ ) ]] || {
        echo "Error: --title needs a non-negative integer or all" >&2
        usage 2
      }
      AUDIO_UTILS_BD_TITLE=$2
      shift 2
      ;;
    --minlength)
      [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || {
        echo "Error: --minlength needs a non-negative integer" >&2
        usage 2
      }
      AUDIO_UTILS_BD_MIN_LENGTH=$2
      shift 2
      ;;
    --allow-float-reduction) AUDIO_UTILS_BD_ALLOW_FLOAT=1; shift ;;
    --split-chapters) AUDIO_UTILS_BD_SPLIT_CHAPTERS=1; shift ;;
    --stage-dir)
      [[ $# -ge 2 && -n "$2" ]] || { echo "Error: --stage-dir needs a directory" >&2; usage 2; }
      AUDIO_UTILS_BD_STAGE_DIR=$2
      shift 2
      ;;
    --verify-archive)
      [[ $# -ge 2 && -n "$2" ]] || { echo "Error: --verify-archive needs a directory" >&2; usage 2; }
      VERIFY_ARCHIVE=$2
      shift 2
      ;;
    --audit-archive)
      [[ $# -ge 2 && -n "$2" ]] || { echo "Error: --audit-archive needs a directory" >&2; usage 2; }
      AUDIT_ARCHIVE=$2
      shift 2
      ;;
    --preserve-streams) AUDIO_UTILS_BD_PRESERVE_STREAMS=1; shift ;;
    --sign-key)
      [[ $# -ge 2 && -f "$2" ]] || { echo "Error: --sign-key needs a key file" >&2; usage 2; }
      AUDIO_UTILS_BD_SIGN_KEY=$2
      shift 2
      ;;
    --par2-percent)
      [[ $# -ge 2 && "$2" =~ ^[0-9]+$ && "$2" -le 100 ]] || {
        echo "Error: --par2-percent needs an integer from 0 to 100" >&2; usage 2;
      }
      AUDIO_UTILS_BD_PAR2_PERCENT=$2
      shift 2
      ;;
    --seal) AUDIO_UTILS_BD_SEAL=1; shift ;;
    -n) DRY_RUN=1; shift ;;
    -y) OVERWRITE=1; shift ;;
    -q) QUIET=1; shift ;;
    -v) VERBOSE=1; shift ;;
    -h|--help) usage 0 ;;
    --version) audio_utils_print_version "bluray-to-flac"; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage 2
      ;;
    *) break ;;
  esac
done

[[ "$AUDIO_UTILS_BD_TITLE" == all || "$AUDIO_UTILS_BD_TITLE" =~ ^[0-9]+$ ]] || {
  echo "Error: AUDIO_UTILS_BD_TITLE needs a non-negative integer or all" >&2
  exit 2
}
[[ "$AUDIO_UTILS_BD_MIN_LENGTH" =~ ^[0-9]+$ ]] || {
  echo "Error: AUDIO_UTILS_BD_MIN_LENGTH needs a non-negative integer" >&2
  exit 2
}
[[ "$AUDIO_UTILS_BD_ALLOW_FLOAT" == 0 || "$AUDIO_UTILS_BD_ALLOW_FLOAT" == 1 ]] || {
  echo "Error: AUDIO_UTILS_BD_ALLOW_FLOAT needs 0 or 1" >&2
  exit 2
}
[[ "$AUDIO_UTILS_BD_SPLIT_CHAPTERS" == 0 || "$AUDIO_UTILS_BD_SPLIT_CHAPTERS" == 1 ]] || {
  echo "Error: AUDIO_UTILS_BD_SPLIT_CHAPTERS needs 0 or 1" >&2
  exit 2
}
for flag in AUDIO_UTILS_BD_PRESERVE_STREAMS AUDIO_UTILS_BD_SEAL; do
  [[ "${!flag}" == 0 || "${!flag}" == 1 ]] || { echo "Error: $flag needs 0 or 1" >&2; exit 2; }
done
[[ "$AUDIO_UTILS_BD_PAR2_PERCENT" =~ ^[0-9]+$ && "$AUDIO_UTILS_BD_PAR2_PERCENT" -le 100 ]] || {
  echo "Error: AUDIO_UTILS_BD_PAR2_PERCENT needs 0..100" >&2; exit 2;
}
if [[ -n "${AUDIO_UTILS_BD_DISC_ID:-}" && \
  ! "$AUDIO_UTILS_BD_DISC_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Error: AUDIO_UTILS_BD_DISC_ID contains unsafe characters" >&2
  exit 2
fi

if [[ -n "$BD_DEVICE" ]]; then
  AUDIO_UTILS_BD_DEVICE="$BD_DEVICE"
  export AUDIO_UTILS_BD_DEVICE
fi

export DRY_RUN OVERWRITE DELETE_SOURCE QUIET VERBOSE
export AUDIO_UTILS_BD_TITLE AUDIO_UTILS_BD_MIN_LENGTH AUDIO_UTILS_BD_DISC_ID
export AUDIO_UTILS_BD_ALLOW_FLOAT AUDIO_UTILS_BD_STAGE_DIR
export AUDIO_UTILS_BD_SPLIT_CHAPTERS
export AUDIO_UTILS_BD_PRESERVE_STREAMS AUDIO_UTILS_BD_SIGN_KEY AUDIO_UTILS_BD_SIGN_PUBKEY
export AUDIO_UTILS_BD_PAR2_PERCENT AUDIO_UTILS_BD_SEAL
: "${FAIL_LOG:=$(audio_utils_state_dir bluray-to-flac)/failures.log}"
: "${SUCCESS_LOG:=$(audio_utils_state_dir bluray-to-flac)/success.csv}"
export FAIL_LOG SUCCESS_LOG

plugin_require_deps || exit 2
if [[ -n "$AUDIO_UTILS_BD_SIGN_KEY" ]] && ! command -v minisign >/dev/null 2>&1; then
  echo "Error: minisign is required by --sign-key" >&2; exit 2
fi
if ((AUDIO_UTILS_BD_PAR2_PERCENT > 0)) && ! command -v par2 >/dev/null 2>&1; then
  echo "Error: par2 is required by --par2-percent" >&2; exit 2
fi
if [[ -n "$VERIFY_ARCHIVE" ]]; then
  bluray_verify_archive "$VERIFY_ARCHIVE" || exit 1
  exit 0
fi
if [[ -n "$AUDIT_ARCHIVE" ]]; then
  bluray_audit_archive "$AUDIT_ARCHIVE" || exit 1
  exit 0
fi
init_success_log || exit 2

PATHS=()
if [[ -n "$DIR_FILE" ]]; then
  mapfile -t PATHS <"$DIR_FILE"
fi
while (($# > 0)); do PATHS+=("$1"); shift; done

# -D alone: rip from device
if [[ -n "$BD_DEVICE" ]] && ((${#PATHS[@]} == 0)); then
  PATHS+=("$BD_DEVICE")
fi

if ((${#PATHS[@]} == 0)) && [[ ! -t 0 ]]; then
  if ((DIRS0)); then
    au_mapfile0 PATHS
  else
    mapfile -t PATHS
  fi
fi
if ((${#PATHS[@]} == 0)); then
  echo "Error: no BDMV paths, media, or -D device given" >&2
  usage 2
fi

ok=0
fail=0
idx=0
PROGRESS_TOTAL=${#PATHS[@]}
PROGRESS_START=$(date +%s)
export PROGRESS_TOTAL PROGRESS_START

for p in "${PATHS[@]}"; do
  [[ -z "${p// }" ]] && continue
  ((++idx))
  export PROGRESS_INDEX=$idx
  if convert_one "$p"; then ((ok++)) || true
  else ((fail++)) || true; fi
done

elapsed=$(( $(date +%s) - PROGRESS_START ))
log_always "Done. ok=$ok failed=$fail elapsed=$(fmt_dur "$elapsed")"
[[ "$fail" -eq 0 ]]
