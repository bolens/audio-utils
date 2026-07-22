#!/usr/bin/env bash
# Report or rmdir one empty directory.

convert_one() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    log_fail "$dir" "not a directory"
    return 1
  fi

  if ! LC_ALL=C find -P "$dir" -maxdepth 0 -type d -empty | grep -q .; then
    log_progress "skip (not empty): $dir"
    log_success "$dir" "skip" "" "" "not-empty"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if [[ "${EMPTY_DELETE:-0}" -eq 1 ]]; then
      log_progress "would remove: $dir"
    else
      log_progress "would report: $dir"
    fi
    return 0
  fi

  if [[ "${EMPTY_DELETE:-0}" -eq 1 ]]; then
    if ! rmdir -- "$dir"; then
      log_fail "$dir" "rmdir failed"
      return 1
    fi
    log_progress "removed: $dir"
    log_success "$dir" "removed" "" "" "empty"
    return 0
  fi

  log_fail "$dir" "empty directory"
  return 1
}
