#!/usr/bin/env bash
# Shared logging helpers (stderr). Relies on QUIET / VERBOSE / DRY_RUN / FAIL_LOG.
# When AU_STDERR_LOCK is set (parallel -j), line/block writes hold flock so
# multi-line FAIL reports and progress lines do not interleave mid-message.

# Print one line to stderr (optional flock when AU_STDERR_LOCK is set).
_au_stderr_line() {
  if [[ -n "${AU_STDERR_LOCK:-}" ]]; then
    (
      flock 9
      printf '%s\n' "$*"
    ) 9>>"${AU_STDERR_LOCK}" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

# Print stdin to stderr as one locked block (multi-line FAIL reports).
_au_stderr_block() {
  if [[ -n "${AU_STDERR_LOCK:-}" ]]; then
    (
      flock 9
      cat
    ) 9>>"${AU_STDERR_LOCK}" >&2
  else
    cat >&2
  fi
}

log_info() {
  [[ "${QUIET:-0}" -eq 1 ]] && return 0
  # stderr: must not pollute command substitutions
  _au_stderr_line "$*"
}

log_note() {
  [[ "${VERBOSE:-0}" -eq 1 ]] || return 0
  _au_stderr_line "$*"
}

log_verbose() {
  [[ "${VERBOSE:-0}" -eq 1 ]] || return 0
  _au_stderr_line "$*"
}

log_always() {
  _au_stderr_line "$*"
}

log_err() {
  _au_stderr_line "$*"
}

human_bytes() {
  local n=${1:-0}
  numfmt --to=iec --suffix=B "$n" 2>/dev/null || printf '%sB' "$n"
}

# Flatten an error file to one log-friendly line (first N lines).
err_snippet() {
  local f=$1
  local max=${2:-12}
  [[ -s "$f" ]] || return 0
  head -n "$max" "$f" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

# Stash stderr from a tool for the next log_fail (cleared after use).
set_last_err_file() {
  local f=$1
  AUDIO_UTILS_LAST_ERR=$(err_snippet "$f")
  export AUDIO_UTILS_LAST_ERR
}

clear_last_err() {
  AUDIO_UTILS_LAST_ERR=""
}

# flock-protected append (parallel-safe). Ensures mode 600 on the file.
append_locked() {
  local file="$1"
  shift
  (
    flock 9
    # shellcheck disable=SC2059
    printf "$@" >&9
  ) 9>>"${file}"
  chmod 600 -- "$file" 2>/dev/null || true
}

csv_escape() {
  local s=$1
  s=${s//\"/\"\"}
  printf '"%s"' "$s"
}

json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '"%s"' "$s"
}

# Probe fields for debugging (best-effort; never fails the caller).
probe_debug_fields() {
  local path=$1
  local codec bytes samples
  codec=$(audio_codec "$path" 2>/dev/null || true)
  bytes=$(file_bytes "$path" 2>/dev/null || echo 0)
  samples=$(audio_samples "$path" 2>/dev/null || true)
  printf '%s\t%s\t%s\n' "${codec:-?}" "${bytes:-0}" "${samples:-?}"
}

# Write failure-log header (TSV) or no-op for .jsonl.
init_fail_log() {
  [[ "${DRY_RUN:-0}" -eq 1 || -z "${FAIL_LOG:-}" ]] && return 0
  audio_utils_ensure_log_file "$FAIL_LOG" truncate || return 1
  case "${FAIL_LOG}" in
    *.jsonl) ;;
    *)
      printf '%s\n' \
        'timestamp	path	reason	detail	codec	bytes	samples	progress' \
        >"${FAIL_LOG}"
      chmod 600 -- "${FAIL_LOG}" 2>/dev/null || true
      ;;
  esac
  log_info "Failure log: ${FAIL_LOG}"
}

# Wide failure report → stderr always; append FAIL_LOG when set.
# Usage: log_fail PATH REASON [DETAIL]
log_fail() {
  local path="$1"
  local reason="$2"
  local detail="${3:-}"
  local codec bytes samples progress ts human
  local idx="${PROGRESS_INDEX:-}"
  local total="${PROGRESS_TOTAL:-}"

  if [[ -n "${AUDIO_UTILS_LAST_ERR:-}" ]]; then
    if [[ -n "$detail" ]]; then
      detail="${detail} | ${AUDIO_UTILS_LAST_ERR}"
    else
      detail="$AUDIO_UTILS_LAST_ERR"
    fi
  fi
  clear_last_err

  IFS=$'\t' read -r codec bytes samples < <(probe_debug_fields "$path")
  human=$(human_bytes "${bytes:-0}")
  ts=$(au_iso_timestamp)
  if [[ -n "$idx" && -n "$total" ]]; then
    progress="${idx}/${total}"
  else
    progress="-"
  fi

  # Multi-line stderr block - always shown (even under -q).
  {
    printf 'FAIL [%s] %s\n' "$progress" "$path"
    printf '  reason:   %s\n' "$reason"
    if [[ -n "$detail" ]]; then
      printf '  detail:   %s\n' "$detail"
    fi
    printf '  probe:    codec=%s  size=%s (%s)  samples=%s\n' \
      "${codec:-?}" "${bytes:-0}" "$human" "${samples:-?}"
    printf '  time:     %s\n' "$ts"
  } | _au_stderr_block

  if [[ "${DRY_RUN:-0}" -eq 0 && -n "${FAIL_LOG:-}" ]]; then
    case "${FAIL_LOG}" in
      *.jsonl)
        append_locked "${FAIL_LOG}" \
          '{"ts":"%s","path":%s,"reason":%s,"detail":%s,"codec":%s,"bytes":%s,"samples":%s,"progress":%s}\n' \
          "$ts" \
          "$(json_str "$path")" \
          "$(json_str "$reason")" \
          "$(json_str "$detail")" \
          "$(json_str "${codec:-}")" \
          "${bytes:-0}" \
          "$(json_str "${samples:-}")" \
          "$(json_str "$progress")"
        ;;
      *)
        append_locked "${FAIL_LOG}" '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$ts" \
          "$path" \
          "$reason" \
          "$detail" \
          "${codec:-}" \
          "${bytes:-0}" \
          "${samples:-}" \
          "$progress"
        ;;
    esac
  fi
}
