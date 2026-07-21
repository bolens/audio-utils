#!/usr/bin/env bash
# Classify one file as junk; report or delete it.

# Print why PATH is junk; return 1 when it is not junk.
_junk_reason() {
  local f=$1 base
  base=$(basename -- "$f")
  case "${base,,}" in
    thumbs.db | desktop.ini | .ds_store | .directory)
      printf 'junk-name:%s\n' "$base"
      return 0
      ;;
    ._*)
      printf 'appledouble\n'
      return 0
      ;;
  esac
  if [[ -f "$f" && ! -s "$f" ]]; then
    printf 'zero-byte\n'
    return 0
  fi
  return 1
}

convert_one() {
  local f="$1" why

  why=$(_junk_reason "$f") || {
    # Should not happen after plugin_accept_source; treat as clean.
    log_progress "skip (not junk): $f"
    log_success "$f" "skip" "" "" "not-junk"
    return 0
  }

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if [[ "${JUNK_DELETE:-0}" -eq 1 ]]; then
      log_progress "would delete: $f ($why)"
    else
      log_progress "would report: $f ($why)"
    fi
    return 0
  fi

  if [[ "${JUNK_DELETE:-0}" -eq 1 ]]; then
    if ! rm -f -- "$f"; then
      log_fail "$f" "delete failed" "$why"
      return 1
    fi
    log_progress "deleted: $f ($why)"
    log_success "$f" "deleted" "" "" "$why"
    return 0
  fi

  # Report mode: junk present is a failure (like an audit)
  log_fail "$f" "junk file" "$why"
  return 1
}
