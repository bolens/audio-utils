#!/usr/bin/env bash
# Progress / ETA helpers. Uses PROGRESS_INDEX / TOTAL / START (epoch seconds).

fmt_dur() {
  local s=${1:-0}
  ((s < 0)) && s=0
  printf '%d:%02d:%02d' $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

# Sets human-readable progress prefix into PROGRESS_PREFIX
progress_prefix() {
  local idx="${PROGRESS_INDEX:-0}"
  local total="${PROGRESS_TOTAL:-0}"
  local start="${PROGRESS_START:-0}"
  local now elapsed remain eta_s

  if ((total <= 0)); then
    PROGRESS_PREFIX=""
    return 0
  fi

  now=$(date +%s)
  elapsed=$((now - start))
  if ((idx > 0 && elapsed > 0 && idx < total)); then
    remain=$((total - idx))
    eta_s=$((elapsed * remain / idx))
    PROGRESS_PREFIX="[${idx}/${total} elapsed=$(fmt_dur "$elapsed") eta=$(fmt_dur "$eta_s")] "
  elif ((idx > 0)); then
    PROGRESS_PREFIX="[${idx}/${total} elapsed=$(fmt_dur "$elapsed")] "
  else
    PROGRESS_PREFIX="[${idx}/${total}] "
  fi
}

log_progress() {
  progress_prefix
  # Progress always prints (even in -q); quiet only hides notes/details.
  # Prefer _au_stderr_line when log.sh is loaded (parallel-safe under -j).
  if declare -F _au_stderr_line >/dev/null 2>&1; then
    _au_stderr_line "${PROGRESS_PREFIX}$*"
  else
    printf '%s\n' "${PROGRESS_PREFIX}$*" >&2
  fi
}
