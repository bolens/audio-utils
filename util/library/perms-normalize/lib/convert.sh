#!/usr/bin/env bash
# Check (or chmod) one file; parent dir handled once per directory.

# Normalize an octal mode string for comparison ("0644" → "644").
# Input is pre-validated as octal by plugin_after_flags.
_perms_canon() {
  printf '%o' "$((8#$1))"
}

convert_one() {
  local f="$1" mode want dir dmode dwant key
  local -a issues=()

  want=$(_perms_canon "$PERMS_FILE_MODE")
  dwant=$(_perms_canon "$PERMS_DIR_MODE")

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would perms-check: $f"; return 0
  fi

  mode=$(stat -c '%a' -- "$f" 2>/dev/null) || {
    log_fail "$f" "stat failed"
    return 1
  }

  if [[ "$mode" != "$want" ]]; then
    if [[ "${PERMS_APPLY:-0}" -eq 1 ]]; then
      if chmod "$want" -- "$f"; then
        log_progress "chmod ${mode}→${want}: $f"
      else
        log_fail "$f" "chmod failed" "mode=$mode want=$want"
        return 1
      fi
    else
      issues+=("file-mode:${mode}!=${want}")
    fi
  fi

  # Parent directory: first file in each dir claims the check.
  dir=$(cd -- "$(dirname -- "$f")" && pwd) || {
    log_fail "$f" "cannot resolve directory"
    return 1
  }
  key=$(au_sha256_str "$dir")
  if mkdir -- "${AU_PERMS_STATE:?}/${key}" 2>/dev/null; then
    dmode=$(stat -c '%a' -- "$dir" 2>/dev/null) || dmode=""
    if [[ -n "$dmode" && "$dmode" != "$dwant" ]]; then
      if [[ "${PERMS_APPLY:-0}" -eq 1 ]]; then
        if chmod "$dwant" -- "$dir"; then
          log_progress "chmod ${dmode}→${dwant}: $dir"
        else
          issues+=("dir-chmod-failed:${dir}")
        fi
      else
        issues+=("dir-mode:${dmode}!=${dwant}:${dir}")
      fi
    fi
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$f" "non-conforming permissions" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $f"
  log_success "$f" "clean" "" "" "mode=$want"
}
