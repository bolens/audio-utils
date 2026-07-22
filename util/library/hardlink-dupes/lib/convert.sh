#!/usr/bin/env bash
# Content-key index + optional hardlink of duplicate FLACs to the keeper inode.

_hl_content_key() {
  local flac=$1 key="" stream

  if [[ "${HL_DECODE_MD5:-0}" -eq 1 ]]; then
    key=$(audio_md5 "$flac") || true
    [[ -n "$key" ]] || return 1
    printf 'dec:%s\n' "$key"
    return 0
  fi

  stream=$(metaflac --show-md5sum -- "$flac" 2>/dev/null || true)
  stream=${stream,,}
  if [[ -z "$stream" || "$stream" == "00000000000000000000000000000000" ]]; then
    key=$(audio_md5 "$flac") || true
    [[ -n "$key" ]] || return 1
    printf 'dec:%s\n' "$key"
    return 0
  fi
  printf 'si:%s\n' "$stream"
}

# Register path under key. Prints keeper path if this is a duplicate; else empty + exit 1.
_hl_register() {
  local key=$1 path=$2
  local index="${AU_HL_STATE:?}/index.tsv"
  local lock="${AU_HL_STATE}/index.lock"
  local first="" k p

  (
    flock 9
    if [[ -f "$index" ]]; then
      while IFS=$'\t' read -r k p || [[ -n "$k" ]]; do
        if [[ "$k" == "$key" ]]; then
          first=$p
          break
        fi
      done <"$index"
    fi
    printf '%s\t%s\n' "$key" "$path" >>"$index"
    if [[ -n "$first" ]]; then
      printf '%s\n' "$first"
      exit 0
    fi
    exit 1
  ) 9>"$lock"
}

_hl_same_inode() {
  local a=$1 b=$2
  local ia ib
  ia=$(stat -c '%d:%i' -- "$a" 2>/dev/null) || return 1
  ib=$(stat -c '%d:%i' -- "$b" 2>/dev/null) || return 1
  [[ "$ia" == "$ib" ]]
}

_hl_same_fs() {
  local a=$1 b=$2
  local da db
  da=$(stat -c '%d' -- "$a" 2>/dev/null) || return 1
  db=$(stat -c '%d' -- "$b" 2>/dev/null) || return 1
  [[ "$da" == "$db" ]]
}

_hl_link_to_keeper() {
  local dup=$1 keeper=$2
  local dir tmp

  dir=$(dirname -- "$dup")
  tmp="${dir}/.hl.${RANDOM}.$$"
  if ! ln -- "$keeper" "$tmp" 2>/dev/null; then
    return 1
  fi
  if ! mv -f -- "$tmp" "$dup"; then
    rm -f -- "$tmp" 2>/dev/null || true
    return 1
  fi
  printf '%s\t%s\n' "$dup" "$keeper" >>"${AU_HL_STATE}/linked.tsv"
  return 0
}

convert_one() {
  local flac="$1" key keeper abs mode

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would hardlink-check: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  abs=$(au_abspath "$flac")
  if ! key=$(_hl_content_key "$flac"); then
    log_fail "$flac" "content key failed"
    return 1
  fi

  if [[ "${HL_DECODE_MD5:-0}" -eq 1 ]]; then
    mode="decode-md5"
  else
    mode="streaminfo-md5"
  fi

  if ! keeper=$(_hl_register "$key" "$abs"); then
    log_progress "keeper: $flac"
    log_success "$flac" "$mode" "${key#*:}" "$(file_sha256 "$flac")" "first"
    return 0
  fi

  if _hl_same_inode "$abs" "$keeper"; then
    log_progress "already hardlinked: $flac -> $keeper"
    log_success "$flac" "$mode" "${key#*:}" "$(file_sha256 "$flac")" "already-linked"
    return 0
  fi

  if [[ "${HL_CROSS_FS:-0}" -eq 0 ]] && ! _hl_same_fs "$abs" "$keeper"; then
    log_fail "$flac" "duplicate on different filesystem" "keeper=$keeper"
    return 1
  fi

  if [[ "${HL_APPLY:-0}" -eq 0 ]]; then
    log_fail "$flac" "hardlink candidate" "keeper=$keeper;key=${key:0:48}"
    return 1
  fi

  if ! _hl_link_to_keeper "$abs" "$keeper"; then
    log_fail "$flac" "hardlink failed" "keeper=$keeper"
    return 1
  fi

  log_progress "hardlinked: $flac -> $keeper"
  log_success "$flac" "linked" "${key#*:}" "$(file_sha256 "$flac")" "keeper=$keeper"
}
