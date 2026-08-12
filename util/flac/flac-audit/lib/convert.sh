#!/usr/bin/env bash
# Audit one FLAC: integrity, core tags, cover presence, leftover PCM siblings.

_audit_tag_value() {
  local flac=$1 tag=$2
  local line
  line=$(metaflac --show-tag="$tag" -- "$flac" 2>/dev/null | head -n1)
  # metaflac prints TAG=value
  if [[ "$line" == *=* ]]; then
    printf '%s\n' "${line#*=}"
  else
    printf '%s\n' "$line"
  fi
}

_audit_leftover_pcm() {
  local flac=$1
  local base ext ue
  base=${flac%.*}
  : "${AU_AUDIO_EXTS_PCM:=wav aiff aif caf}"
  # shellcheck disable=SC2086
  for ext in $AU_AUDIO_EXTS_PCM; do
    if [[ -f "${base}.${ext}" ]]; then
      printf '%s\n' "${base}.${ext}"
      return 0
    fi
    ue=${ext^^}
    if [[ "$ue" != "$ext" && -f "${base}.${ue}" ]]; then
      printf '%s\n' "${base}.${ue}"
      return 0
    fi
  done
  return 1
}

convert_one() {
  local flac="$1"
  local issues=() missing_tags=() tag val leftover sha

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would audit: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  for tag in ARTIST ALBUM TITLE TRACKNUMBER; do
    val=$(_audit_tag_value "$flac" "$tag")
    val=${val#"${val%%[![:space:]]*}"}
    val=${val%"${val##*[![:space:]]}"}
    if [[ -z "$val" ]]; then
      missing_tags+=("$tag")
    fi
  done
  if ((${#missing_tags[@]} > 0)); then
    local IFS=,
    issues+=("missing-tags:${missing_tags[*]}")
  fi

  if ! audio_valid_cover "$flac"; then
    issues+=("missing-or-invalid-cover")
  fi

  if leftover=$(_audit_leftover_pcm "$flac"); then
    issues+=("leftover-pcm:$(basename -- "$leftover")")
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$flac" "audit issues" "${issues[*]}"
    return 1
  fi

  sha=$(file_sha256 "$flac")
  log_progress "ok: $flac"
  log_success "$flac" "clean" "" "$sha" "ok"
}
