#!/usr/bin/env bash
# Thin GNU/Linux helpers — single call sites for portability seams.
# Implementations assume GNU coreutils/findutils/util-linux (see docs/requirements.md).

# Absolute path for PATH (best-effort). Prints without trailing newline.
au_abspath() {
  local p="$1" out
  out=$(readlink -f -- "$p" 2>/dev/null || realpath -- "$p" 2>/dev/null || true)
  if [[ -n "$out" ]]; then
    printf '%s' "$out"
    return 0
  fi
  if [[ -d "$p" ]]; then
    out=$(cd -- "$p" && pwd -P) 2>/dev/null || out=$p
    printf '%s' "$out"
  else
    local d b
    d=$(dirname -- "$p")
    b=$(basename -- "$p")
    out=$(cd -- "$d" 2>/dev/null && pwd -P || printf '%s' "$d")
    printf '%s/%s' "$out" "$b"
  fi
}

# File size in bytes; 0 on failure.
au_file_bytes() {
  stat -c%s -- "$1" 2>/dev/null || echo 0
}

# SHA-256 hex digest of a file.
au_sha256() {
  sha256sum -- "$1" | awk '{print $1}'
}

# SHA-256 hex digest of a string (stdin via printf).
au_sha256_str() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

# Free bytes on the filesystem containing PATH.
au_bytes_avail() {
  df -B1 --output=avail "$1" 2>/dev/null | tail -n1 | tr -d ' '
}

# ISO-8601 timestamp with seconds (GNU date -Iseconds).
au_iso_timestamp() {
  date -Iseconds
}

# Detect CPU count (nproc, then sysctl, then fallback).
au_cpu_count() {
  local n
  n=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
  [[ "$n" =~ ^[0-9]+$ ]] || n=4
  printf '%s\n' "$n"
}

# Resolve find binary: AUDIO_UTILS_FIND or find.
au_find_bin() {
  printf '%s\n' "${AUDIO_UTILS_FIND:-find}"
}

# True if NAME.so* is visible via ldconfig or common lib dirs (incl. /usr/lib64).
au_so_present() {
  local name="$1" hit
  [[ -n "$name" ]] || return 1
  if command -v ldconfig >/dev/null 2>&1; then
    if ldconfig -p 2>/dev/null | grep -qiE "${name}\\.so"; then
      return 0
    fi
  fi
  for hit in \
    /usr/lib/"${name}".so* \
    /usr/lib/*/"${name}".so* \
    /usr/lib64/"${name}".so* \
    /usr/lib64/*/"${name}".so* \
    /usr/local/lib/"${name}".so* \
    /usr/local/lib64/"${name}".so*; do
    # shellcheck disable=SC2086
    if compgen -G "$hit" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}
