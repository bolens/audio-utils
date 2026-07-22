#!/usr/bin/env bash
# Strip padding / APPLICATION blocks; optional core-tag-only mode.

_CORE_TAGS=(ARTIST ALBUMARTIST ALBUM TITLE TRACKNUMBER TRACKTOTAL DISCNUMBER \
  DISCTOTAL DATE GENRE COMPOSER)

convert_one() {
  local flac="$1"
  local before after sha mode notes="" tag val
  local -a keep=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would strip: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  before=$(file_bytes "$flac")
  mode="padding"

  # Remove padding and APPLICATION (seektable kept; pictures optional)
  metaflac --remove --block-type=PADDING,APPLICATION --dont-use-padding -- "$flac" \
    2>/dev/null || true

  if [[ "${STRIP_KEEP_PICTURE:-1}" -eq 0 ]]; then
    metaflac --remove --block-type=PICTURE --dont-use-padding -- "$flac" 2>/dev/null || true
    notes="pictures-removed"
  fi

  if [[ "${STRIP_CORE_ONLY:-0}" -eq 1 ]]; then
    mode="core-tags"
    for tag in "${_CORE_TAGS[@]}"; do
      val=$(flac_tag_get "$flac" "$tag")
      val=$(flac_tag_trim "$val")
      [[ -n "$val" ]] || continue
      keep+=("${tag}=${val}")
    done
    if ! metaflac --remove-all-tags -- "$flac"; then
      log_fail "$flac" "remove-all-tags failed"
      return 1
    fi
    for val in "${keep[@]}"; do
      if ! metaflac --set-tag="$val" -- "$flac"; then
        log_fail "$flac" "restore core tag failed" "tag=${val%%=*}"
        return 1
      fi
    done
    notes="${notes:+$notes;}core=${#keep[@]}"
  fi

  # Rebuild seek table for good measure (ignore failure on odd files)
  metaflac --add-seekpoint=10s -- "$flac" 2>/dev/null || true

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed after strip"
    return 1
  fi

  after=$(file_bytes "$flac")
  sha=$(file_sha256 "$flac")
  log_progress "stripped: $flac ($before -> $after)"
  log_success "$flac" "$mode" "" "$sha" "bytes:${before}->${after};${notes:-ok}"
}
