#!/usr/bin/env bash
# Audit one ripper .log: detect ripper, Secure mode, CRC / AccurateRip health.

# Detect ripper family from log text. Prints: eac|xld|whipper|cuetools|unknown
_riplog_detect() {
  local log=$1 head
  head=$(head -n 40 -- "$log" 2>/dev/null || true)
  if printf '%s\n' "$head" | grep -qiE 'Exact Audio Copy|EAC extraction logfile'; then
    printf 'eac\n'; return 0
  fi
  if printf '%s\n' "$head" | grep -qiE '^XLD |X Lossless Decoder'; then
    printf 'xld\n'; return 0
  fi
  if printf '%s\n' "$head" | grep -qiE 'whipper|morituri'; then
    printf 'whipper\n'; return 0
  fi
  if printf '%s\n' "$head" | grep -qiE 'CUETools|CUERipper'; then
    printf 'cuetools\n'; return 0
  fi
  if grep -qiE 'Exact Audio Copy|EAC extraction logfile' -- "$log" 2>/dev/null; then
    printf 'eac\n'; return 0
  fi
  if grep -qiE '^XLD |X Lossless Decoder' -- "$log" 2>/dev/null; then
    printf 'xld\n'; return 0
  fi
  if grep -qiE 'whipper|morituri' -- "$log" 2>/dev/null; then
    printf 'whipper\n'; return 0
  fi
  if grep -qiE 'CUETools|CUERipper' -- "$log" 2>/dev/null; then
    printf 'cuetools\n'; return 0
  fi
  printf 'unknown\n'
}

# Print one issue per line for EAC-style logs.
_riplog_audit_eac() {
  local log=$1
  local strict=${RIPLOG_STRICT:-0}

  if ! grep -qiE 'Read mode[[:space:]]*:[[:space:]]*Secure|Extraction mode[[:space:]]*:[[:space:]]*Secure' -- "$log"; then
    if grep -qiE 'Read mode[[:space:]]*:|Extraction mode[[:space:]]*:' -- "$log"; then
      printf 'not-secure\n'
    else
      printf 'mode-unknown\n'
    fi
  fi

  if grep -qiE 'Suspicious position|There were errors|Error occurred|Copy aborted' -- "$log"; then
    printf 'rip-errors\n'
  fi

  if grep -qiE 'CRC[[:space:]]+Mismatch' -- "$log"; then
    printf 'crc-mismatch\n'
  elif awk 'BEGIN{IGNORECASE=1}
    /Test CRC/ {t=$NF}
    /Copy CRC/ {
      c=$NF
      if (t != "" && c != "" && tolower(t) != tolower(c)) bad=1
    }
    END { exit bad ? 0 : 1 }' "$log"; then
    printf 'crc-mismatch\n'
  fi

  if grep -qiE 'AccurateRip[[:space:]]+summary|Track[[:space:]]+[0-9]+[[:space:]]+accurately ripped' -- "$log"; then
    if grep -qiE 'cannot be verified|not present in (the )?AccurateRip|AccurateRip.*no match|no AccurateRip' -- "$log"; then
      if [[ "$strict" -eq 1 ]]; then
        printf 'accuraterip-incomplete\n'
      fi
    fi
    if grep -qiE 'AccurateRip[[:space:]]+\[?mismatch|diffs? for track' -- "$log"; then
      printf 'accuraterip-mismatch\n'
    fi
  elif [[ "$strict" -eq 1 ]]; then
    printf 'accuraterip-missing\n'
  fi

  if ! grep -qiE 'All tracks[[:space:]]+(accurately ripped|OK)|No errors occurred|Copy OK' -- "$log"; then
    if grep -qiE 'Copy finished|Extraction successfully completed' -- "$log"; then
      :
    elif [[ "$strict" -eq 1 ]]; then
      printf 'no-ok-summary\n'
    fi
  fi
}

_riplog_audit_xld() {
  local log=$1
  local strict=${RIPLOG_STRICT:-0}

  if ! grep -qiE 'Ripper mode[[:space:]]*:[[:space:]]*XLD Secure Ripper|Used drive memory[[:space:]]*:|[[:space:]]Secure Ripper' -- "$log"; then
    if grep -qiE 'Ripper mode[[:space:]]*:' -- "$log"; then
      printf 'not-secure\n'
    else
      printf 'mode-unknown\n'
    fi
  fi

  if grep -qiE 'CRC[[:space:]]+mismatch|Error[[:space:]]+\[|Damaged sector|Read error' -- "$log"; then
    printf 'rip-errors\n'
  fi

  if grep -qiE 'AccurateRip[[:space:]]+v[12]|AR[[:space:]]+v[12]' -- "$log"; then
    if grep -qiE 'AccurateRip.*NG|AR.*NG|not found in AccurateRip|AccurateRip.*failed' -- "$log"; then
      printf 'accuraterip-mismatch\n'
    fi
  elif [[ "$strict" -eq 1 ]]; then
    printf 'accuraterip-missing\n'
  fi
}

_riplog_audit_whipper() {
  local log=$1
  local strict=${RIPLOG_STRICT:-0}

  if grep -qiE ' rip status[[:space:]]*:[[:space:]]*(False|failed)|ERROR|Traceback' -- "$log"; then
    printf 'rip-errors\n'
  fi

  if grep -qiE 'AccurateRip[[:space:]]+v[12]|AR[[:space:]]+v[12]|accuraterip' -- "$log"; then
    if grep -qiE 'AccurateRip result[[:space:]]*:[[:space:]]*(False|failed)|AR[[:space:]]+result.*False' -- "$log"; then
      printf 'accuraterip-mismatch\n'
    fi
  elif [[ "$strict" -eq 1 ]]; then
    printf 'accuraterip-missing\n'
  fi

  if ! grep -qiE 'All tracks OK|rip successful|Extraction successful' -- "$log"; then
    if [[ "$strict" -eq 1 ]]; then
      printf 'no-ok-summary\n'
    fi
  fi
}

_riplog_audit_cuetools() {
  local log=$1
  local strict=${RIPLOG_STRICT:-0}

  if grep -qiE '\[CTDBERROR\]|CRC mismatch|Errors occurred' -- "$log"; then
    printf 'rip-errors\n'
  fi

  if grep -qiE '\[CTDBTOCID\]|CTDB' -- "$log"; then
    if grep -qiE '\[CTDBERROR\]|cannot be verified|No match' -- "$log"; then
      if [[ "$strict" -eq 1 ]]; then
        printf 'ctdb-incomplete\n'
      fi
    fi
  elif [[ "$strict" -eq 1 ]]; then
    printf 'ctdb-missing\n'
  fi
}

convert_one() {
  local src="$1" kind note
  local -a issues=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would rip-log-audit: $src"
    return 0
  fi

  if [[ ! -s "$src" ]]; then
    log_fail "$src" "empty or missing log"
    return 1
  fi

  if command -v iconv >/dev/null 2>&1; then
    if ! iconv -f UTF-8 -t UTF-8 -- "$src" >/dev/null 2>&1; then
      issues+=("non-utf8")
    fi
  fi

  kind=$(_riplog_detect "$src")
  case "$kind" in
    eac) mapfile -t issues < <(printf '%s\n' "${issues[@]}" ; _riplog_audit_eac "$src") ;;
    xld) mapfile -t issues < <(printf '%s\n' "${issues[@]}" ; _riplog_audit_xld "$src") ;;
    whipper) mapfile -t issues < <(printf '%s\n' "${issues[@]}" ; _riplog_audit_whipper "$src") ;;
    cuetools) mapfile -t issues < <(printf '%s\n' "${issues[@]}" ; _riplog_audit_cuetools "$src") ;;
    unknown) issues+=("unknown-ripper") ;;
  esac
  # Drop empty lines from mapfile
  local -a cleaned=()
  local x
  for x in "${issues[@]}"; do
    [[ -n "$x" ]] && cleaned+=("$x")
  done
  issues=("${cleaned[@]}")

  note="ripper=${kind}"
  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$src" "rip log issues" "${note};${issues[*]}"
    return 1
  fi

  log_progress "ok: $src ($kind)"
  log_success "$src" "clean" "" "$(file_sha256 "$src")" "$note"
}
