#!/usr/bin/env bash
# Report (or delete) PCM files that have a verified FLAC sibling.

convert_one() {
  local pcm="$1" flac base

  base=${pcm%.*}
  flac="${base}.flac"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if [[ -f "$flac" ]]; then
      log_progress "would check-pcm: $pcm (sibling flac exists)"
    else
      log_progress "would note-orphan-pcm: $pcm"
    fi
    return 0
  fi

  if [[ ! -f "$flac" ]]; then
    log_fail "$pcm" "no FLAC sibling" "expected=$flac"
    return 1
  fi

  if ! flac_ok "$flac"; then
    log_fail "$pcm" "FLAC sibling corrupt" "flac=$flac"
    return 1
  fi

  if ! sibling_matches_source "$pcm" "$flac"; then
    log_fail "$pcm" "FLAC sibling audio MD5 mismatch" "flac=$flac"
    return 1
  fi

  if [[ "${PCM_DELETE:-0}" -eq 1 ]]; then
    if ! rm -f -- "$pcm"; then
      log_fail "$pcm" "delete failed"; return 1
    fi
    log_progress "deleted: $pcm"
    log_success "$pcm" "deleted" "" "" "flac-ok"
    return 0
  fi

  # Report mode: leftover PCM with good sibling is a failure (like audit)
  log_fail "$pcm" "leftover PCM (verified FLAC sibling exists)" "flac=$flac"
  return 1
}
