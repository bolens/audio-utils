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

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/load.sh
source "${SCRIPT_DIR}/lib/load.sh"
audio_utils_load_config

DELETE_FLAC=0
DELETE_EXISTING=0
DRY_RUN=0
OVERWRITE=0
QUIET=0
VERBOSE=0
JOBS=""
DIR_FILE=""
FAIL_LOG="$(audio_utils_state_dir_path flac-to-wav)/failures.log"
SUCCESS_LOG="$(audio_utils_state_dir_path flac-to-wav)/success.csv"
FAIL_LOG_DEFAULT=1
SUCCESS_LOG_DEFAULT=1
DIRS=()

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

for _arg in "$@"; do
  case "$_arg" in
    --version) audio_utils_print_version "flac-to-wav"; exit 0 ;;
    --help) usage 0 ;;
  esac
done

while getopts ":f:dDL:S:nj:qvyh" opt; do
  case "$opt" in
    f) DIR_FILE="$OPTARG" ;;
    d) DELETE_FLAC=1 ;;
    D) DELETE_EXISTING=1 ;;
    L) FAIL_LOG="$OPTARG"; FAIL_LOG_DEFAULT=0 ;;
    S) SUCCESS_LOG="$OPTARG"; SUCCESS_LOG_DEFAULT=0 ;;
    n) DRY_RUN=1 ;;
    j) JOBS="$OPTARG" ;;
    q) QUIET=1 ;;
    v) VERBOSE=1 ;;
    y) OVERWRITE=1 ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 2 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 2 ;;
  esac
done
shift $((OPTIND - 1))
DIRS+=("$@")

if [[ -n "$DIR_FILE" ]]; then
  [[ -f "$DIR_FILE" ]] || { echo "Error: file not found: $DIR_FILE" >&2; exit 2; }
  mapfile -t file_dirs < <(grep -v '^[[:space:]]*$' "$DIR_FILE" | grep -v '^#')
  DIRS+=("${file_dirs[@]}")
fi

if [[ ! -t 0 ]]; then
  mapfile -t stdin_dirs
  DIRS+=("${stdin_dirs[@]}")
fi

if ((${#DIRS[@]} == 0)); then
  echo "Error: no directories given." >&2
  usage 2
fi

if [[ "$QUIET" -eq 1 && "$VERBOSE" -eq 1 ]]; then
  echo "Note: -q and -v both set; using verbose." >&2
  QUIET=0
fi

if [[ "$DELETE_EXISTING" -eq 1 ]]; then
  if [[ "$DELETE_FLAC" -eq 1 || "$OVERWRITE" -eq 1 ]]; then
    echo "Note: -D is cleanup-only; -d/-y ignored." >&2
  fi
  DELETE_FLAC=0
  OVERWRITE=0
fi

if [[ -z "$JOBS" ]]; then
  JOBS=$(default_jobs)
fi
if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: -j must be a positive integer (got: $JOBS)" >&2
  exit 2
fi

if ! require_cmds flac ffmpeg ffprobe flock; then
  exit 2
fi

init_tmpdir_registry
install_cleanup_trap

ENV_ROOTS=()
audio_utils_roots_from_env ENV_ROOTS || true
sweep_orphans_in_roots "${ENV_ROOTS[@]}" "${DIRS[@]}"

export CHECK_DISK_FACTOR=2

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "$FAIL_LOG_DEFAULT" -eq 1 ]]; then
    FAIL_LOG="$(audio_utils_state_dir flac-to-wav)/failures.log"
  fi
  if [[ "$SUCCESS_LOG_DEFAULT" -eq 1 ]]; then
    SUCCESS_LOG="$(audio_utils_state_dir flac-to-wav)/success.csv"
  fi
  init_fail_log || { echo "Error: cannot write failure log: $FAIL_LOG" >&2; exit 2; }
  init_success_log || exit 2
  log_always "=== $(audio_utils_print_version flac-to-wav | tr -d '\n') ==="
  log_always "start:     $(date -Iseconds)"
  log_always "host:      $(hostname 2>/dev/null || echo unknown)"
  log_always "fail_log:  $FAIL_LOG"
  log_always "success:   $SUCCESS_LOG"
  log_always "jobs:      $JOBS"
fi

export DELETE_FLAC DRY_RUN OVERWRITE DELETE_EXISTING
export FAIL_LOG SUCCESS_LOG QUIET VERBOSE SCRIPT_DIR
export AUDIO_UTILS_TMP_REGISTRY AUDIO_UTILS_WORKDIR_PREFIX CHECK_DISK_FACTOR

ALL_FLACS=()
declare -A DIR_CHECKED=()
pre_fail=0

for dir in "${DIRS[@]}"; do
  dir="${dir#"${dir%%[![:space:]]*}"}"
  dir="${dir%"${dir##*[![:space:]]}"}"
  [[ -z "$dir" ]] && continue

  if [[ ! -d "$dir" ]]; then
    log_always "skip (not a dir): $dir"
    continue
  fi

  mapfile -t flacs < <(LC_ALL=C find -P "$dir" -maxdepth 1 -type f \( -iname '*.flac' \) | LC_ALL=C sort)
  if ((${#flacs[@]} == 0)); then
    log_info "==> $dir"
    log_info "  (no flac files)"
    continue
  fi

  if [[ "$DRY_RUN" -eq 0 && -z "${DIR_CHECKED[$dir]:-}" ]]; then
    sweep_orphan_workdirs "$dir"
    if ! check_disk_space "$dir" "${flacs[@]}"; then
      free=$(bytes_avail "$dir" 2>/dev/null || echo "?")
      for f in "${flacs[@]}"; do
        log_fail "$f" "insufficient disk space in $dir" \
          "need~${CHECK_DISK_FACTOR}x_largest free=$(human_bytes "${free:-0}")"
      done
      ((pre_fail += ${#flacs[@]})) || true
      DIR_CHECKED[$dir]=fail
      continue
    fi
    DIR_CHECKED[$dir]=ok
  fi

  log_info "==> $dir (${#flacs[@]} flacs)"
  ALL_FLACS+=("${flacs[@]}")
done

PROGRESS_TOTAL=${#ALL_FLACS[@]}
PROGRESS_START=$(date +%s)
export PROGRESS_TOTAL PROGRESS_START

finalize_run_logs() {
  local fail_lines success_lines fail_rows
  [[ "$DRY_RUN" -eq 0 ]] || return 0
  if [[ -n "${FAIL_LOG:-}" && -f "$FAIL_LOG" ]]; then
    fail_lines=$(wc -l <"$FAIL_LOG" | tr -d ' ')
    case "$FAIL_LOG" in
      *.jsonl)
        if [[ "${fail_lines:-0}" -eq 0 ]]; then rm -f -- "$FAIL_LOG"
        else log_always "Failures logged to: $FAIL_LOG ($fail_lines events)"; fi
        ;;
      *)
        if [[ "${fail_lines:-0}" -le 1 ]]; then rm -f -- "$FAIL_LOG"
        else
          fail_rows=$((fail_lines - 1))
          log_always "Failures logged to: $FAIL_LOG ($fail_rows events)"
          log_always "  tip: column -t -s \$'\\t' \"$FAIL_LOG\" | less -S"
        fi
        ;;
    esac
  fi
  if [[ -n "${SUCCESS_LOG:-}" && -f "$SUCCESS_LOG" ]]; then
    success_lines=$(wc -l <"$SUCCESS_LOG" | tr -d ' ')
    case "$SUCCESS_LOG" in
      *.jsonl)
        if [[ "${success_lines:-0}" -eq 0 ]]; then rm -f -- "$SUCCESS_LOG"
        else log_always "Success log: $SUCCESS_LOG ($success_lines events)"; fi
        ;;
      *)
        if [[ "${success_lines:-0}" -le 1 ]]; then rm -f -- "$SUCCESS_LOG"
        else
          log_always "Success log: $SUCCESS_LOG ($((success_lines - 1)) rows)"
          log_always "  columns: timestamp,flac,wav,audio_md5,wav_sha256,codec,bytes,samples,notes"
        fi
        ;;
    esac
  fi
}

if ((PROGRESS_TOTAL == 0)); then
  if ((pre_fail > 0)); then
    log_always "Done. nothing converted; $pre_fail failed preflight."
    finalize_run_logs
    exit 1
  fi
  log_always "Done. nothing to do."
  finalize_run_logs
  exit 0
fi

log_info "Jobs: $JOBS  Total files: $PROGRESS_TOTAL"

ok=0
fail=0
kept=0

if [[ "$DELETE_EXISTING" -eq 1 ]]; then
  idx=0
  for flac in "${ALL_FLACS[@]}"; do
    ((++idx))
    export PROGRESS_INDEX=$idx
    wav="${flac%.*}.wav"
    if [[ ! -f "$wav" ]]; then
      log_progress "keep (no wav): $flac"
      ((kept++)) || true
      continue
    fi
    if delete_one_existing "$flac"; then ((ok++)) || true
    else ((fail++)) || true; fi
  done
elif ((JOBS > 1)); then
  STATUS_DIR=$(audio_utils_mktemp_d "status.XXXXXX")
  register_tmpdir "$STATUS_DIR"
  export STATUS_DIR
  idx=0
  args=()
  for flac in "${ALL_FLACS[@]}"; do
    ((++idx))
    args+=("$idx" "$PROGRESS_TOTAL" "$PROGRESS_START" "$flac")
  done
  while IFS= read -r _; do :; done < <(
    printf '%s\0' "${args[@]}" | xargs -0 -n 4 -P "$JOBS" \
      "${SCRIPT_DIR}/lib/worker.sh"
  )
  ok=0
  fail=0
  local_i=0
  for ((local_i = 1; local_i <= PROGRESS_TOTAL; local_i++)); do
    sf="${STATUS_DIR}/${local_i}.status"
    if [[ -f "$sf" ]]; then
      case "$(<"$sf")" in
        OK) ((ok++)) || true ;;
        FAIL) ((fail++)) || true ;;
        *) ((fail++)) || true; log_err "warning: bad status in $sf" ;;
      esac
    else
      ((fail++)) || true
      log_err "warning: missing status for job $local_i/${PROGRESS_TOTAL}"
    fi
  done
  unregister_tmpdir "$STATUS_DIR"
  rm -rf -- "$STATUS_DIR"
else
  idx=0
  for flac in "${ALL_FLACS[@]}"; do
    ((++idx))
    export PROGRESS_INDEX=$idx
    if convert_one "$flac"; then ((ok++)) || true
    else ((fail++)) || true; fi
  done
fi

((fail += pre_fail)) || true
elapsed=$(( $(date +%s) - PROGRESS_START ))
echo
if [[ "$DELETE_EXISTING" -eq 1 ]]; then
  log_always "Done. deleted/ok=$ok kept_no_wav=$kept failed=$fail elapsed=$(fmt_dur "$elapsed")"
else
  log_always "Done. ok=$ok failed=$fail elapsed=$(fmt_dur "$elapsed")"
fi
finalize_run_logs
[[ "$fail" -eq 0 ]]
