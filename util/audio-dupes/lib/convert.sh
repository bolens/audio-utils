#!/usr/bin/env bash
# Detect duplicates across formats via fingerprint (default) or decode MD5.

_dupes_content_key() {
  local f=$1 key="" fp="" dur=""
  if [[ "${DUPES_FINGERPRINT:-1}" -eq 1 ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        DURATION=*) dur=${line#DURATION=} ;;
        FINGERPRINT=*) fp=${line#FINGERPRINT=} ;;
      esac
    done < <(fpcalc -length 120 -- "$f" 2>/dev/null || true)
    if [[ -n "$fp" && -n "$dur" ]]; then
      printf 'fp:%s:%s\n' "$dur" "$fp"
      return 0
    fi
    # Short / silent files often yield empty fingerprints — fall back
  fi
  key=$(audio_md5 "$f") || true
  [[ -n "$key" ]] || return 1
  printf 'dec:%s\n' "$key"
}

_dupes_register() {
  local key=$1 path=$2
  local index="${AU_DUPES_STATE:?}/index.tsv" lock="${AU_DUPES_STATE}/index.lock"
  local first="" k p
  (
    flock 9
    if [[ -f "$index" ]]; then
      while IFS=$'\t' read -r k p || [[ -n "$k" ]]; do
        if [[ "$k" == "$key" ]]; then first=$p; break; fi
      done <"$index"
    fi
    printf '%s\t%s\n' "$key" "$path" >>"$index"
    if [[ -n "$first" ]]; then printf '%s\n' "$first"; exit 0; fi
    exit 1
  ) 9>"$lock"
}

convert_one() {
  local src="$1" key first mode abs
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would check-dupe: $src"; return 0
  fi
  abs=$(au_abspath "$src")
  if ! key=$(_dupes_content_key "$src"); then
    log_fail "$src" "content key failed"; return 1
  fi
  mode="fingerprint"
  [[ "${DUPES_DECODE_MD5:-0}" -eq 1 ]] && mode="decode-md5"
  if first=$(_dupes_register "$key" "$abs"); then
    log_fail "$src" "duplicate of $first" "key=${key:0:48}"
    return 1
  fi
  log_progress "unique: $src"
  log_success "$src" "$mode" "${key#*:}" "$(file_sha256 "$src")" "first"
}
