#!/usr/bin/env bash
# Verify or write sidecar .sha256 / .md5 next to each audio file.

_hash_sum() {
  if [[ "${HASH_ALGO}" == md5 ]]; then
    md5sum -- "$1" | awk '{print $1}'
  else
    sha256sum -- "$1" | awk '{print $1}'
  fi
}

convert_one() {
  local src="$1" side expect got

  side="${src}.${HASH_ALGO}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if [[ "${HASH_WRITE:-0}" -eq 1 ]]; then
      log_progress "would write: $side"
    else
      log_progress "would verify: $src"
    fi
    return 0
  fi

  if [[ "${HASH_WRITE:-0}" -eq 1 ]]; then
    if [[ -f "$side" && "${OVERWRITE:-0}" -eq 0 ]]; then
      log_progress "skip (sidecar exists): $side"
      log_success "$src" "skip" "" "$(file_sha256 "$src")" "exists"
      return 0
    fi
    got=$(_hash_sum "$src") || { log_fail "$src" "hash failed"; return 1; }
    printf '%s  %s\n' "$got" "$(basename -- "$src")" >"$side"
    chmod 600 -- "$side" 2>/dev/null || true
    log_progress "wrote: $side"
    log_success "$src" "write" "" "$got" "sidecar"
    return 0
  fi

  if [[ ! -f "$side" ]]; then
    log_fail "$src" "missing sidecar" "expected=$side"
    return 1
  fi
  expect=$(awk 'NF>=1 {print $1; exit}' "$side")
  got=$(_hash_sum "$src") || { log_fail "$src" "hash failed"; return 1; }
  if [[ "$expect" != "$got" ]]; then
    log_fail "$src" "checksum mismatch" "sidecar=$expect file=$got"
    return 1
  fi
  log_progress "ok: $src"
  log_success "$src" "verify" "" "$got" "match"
}
