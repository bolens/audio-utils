#!/usr/bin/env bash
# Detect duplicate FLACs by STREAMINFO MD5, decode MD5, or chromaprint.

_dupes_content_key() {
  local flac=$1 key="" stream fp dur

  if [[ "${DUPES_FINGERPRINT:-0}" -eq 1 ]]; then
    # FILE=... DURATION=... FINGERPRINT=...
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        DURATION=*) dur=${line#DURATION=} ;;
        FINGERPRINT=*) fp=${line#FINGERPRINT=} ;;
      esac
    done < <(fpcalc -length 120 -- "$flac" 2>/dev/null || true)
    if [[ -n "$fp" && -n "$dur" ]]; then
      printf 'fp:%s:%s\n' "$dur" "$fp"
      return 0
    fi
    return 1
  fi

  if [[ "${DUPES_DECODE_MD5:-0}" -eq 1 ]]; then
    key=$(audio_md5 "$flac") || true
    [[ -n "$key" ]] || return 1
    printf 'dec:%s\n' "$key"
    return 0
  fi

  stream=$(metaflac --show-md5sum -- "$flac" 2>/dev/null || true)
  stream=${stream,,}
  if [[ -z "$stream" || "$stream" == "00000000000000000000000000000000" ]]; then
    # Fall back to decode MD5 when STREAMINFO is empty
    key=$(audio_md5 "$flac") || true
    [[ -n "$key" ]] || return 1
    printf 'dec:%s\n' "$key"
    return 0
  fi
  printf 'si:%s\n' "$stream"
}

_dupes_register() {
  local key=$1 path=$2
  local index="${AU_DUPES_STATE:?}/index.tsv"
  local lock="${AU_DUPES_STATE}/index.lock"
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
    # Always record this path (finalize counts groups with >1 entries)
    printf '%s\t%s\n' "$key" "$path" >>"$index"
    if [[ -n "$first" ]]; then
      printf '%s\n' "$first"
      exit 0
    fi
    exit 1
  ) 9>"$lock"
}

convert_one() {
  local flac="$1"
  local key first mode sha abs

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would check-dupe: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  abs=$(au_abspath "$flac")

  if ! key=$(_dupes_content_key "$flac"); then
    log_fail "$flac" "content key failed"
    return 1
  fi

  if [[ "${DUPES_FINGERPRINT:-0}" -eq 1 ]]; then
    mode="fingerprint"
  elif [[ "${DUPES_DECODE_MD5:-0}" -eq 1 ]]; then
    mode="decode-md5"
  else
    mode="streaminfo-md5"
  fi

  if first=$(_dupes_register "$key" "$abs"); then
    log_fail "$flac" "duplicate of $first" "key=${key:0:48}"
    return 1
  fi

  sha=$(file_sha256 "$flac")
  log_progress "unique: $flac"
  log_success "$flac" "$mode" "${key#*:}" "$sha" "first"
}
