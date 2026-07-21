#!/usr/bin/env bash
# Normalize Vorbis comments on one FLAC (in place).

_tags_should_drop() {
  local key=$1
  if [[ "${TAGS_KEEP_ENCODER:-0}" -eq 1 ]]; then
    local k=${key^^}
    case "$k" in
      ENCODER | ENCODING | TOOL | RIPPER | ENCODEDBY | ENCODED-BY | ENCODED_BY) return 1 ;;
    esac
  fi
  flac_tag_is_junk "$key"
}

_tags_normalize_line() {
  # KEY=value → KEY=value; return 1 to drop
  local line=$1 key val uk
  [[ "$line" == *=* ]] || return 1
  key=${line%%=*}
  val=${line#*=}
  key=$(flac_tag_trim "$key")
  [[ -n "$key" ]] || return 1
  uk=${key^^}
  if _tags_should_drop "$uk"; then
    return 1
  fi
  val=$(flac_tag_trim "$val")
  case "$uk" in
    TRACKNUMBER | TRACK) val=$(flac_tag_normalize_track "$val") ;;
    DATE | YEAR) val=$(flac_tag_normalize_date "$val") ;;
  esac
  if [[ "$uk" == TRACK ]]; then uk=TRACKNUMBER; fi
  if [[ "$uk" == YEAR ]]; then uk=DATE; fi
  printf '%s=%s\n' "$uk" "$val"
}

convert_one() {
  local flac="$1"
  local line norm key val artist aa before after sha notes=""
  local -a out=()
  local -A seen=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would normalize-tags: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  before=$(flac_tag_export "$flac" | LC_ALL=C sort)

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    if ! norm=$(_tags_normalize_line "$line"); then
      continue
    fi
    key=${norm%%=*}
    val=${norm#*=}
    if [[ -n "${seen[$key]:-}" ]]; then
      continue
    fi
    seen[$key]=$val
    out+=("$norm")
  done < <(flac_tag_export "$flac")

  if [[ "${TAGS_FILL_ALBUMARTIST:-0}" -eq 1 ]]; then
    artist=${seen[ARTIST]:-}
    aa=${seen[ALBUMARTIST]:-}
    if [[ -n "$artist" && -z "$aa" ]]; then
      out+=("ALBUMARTIST=$artist")
      seen[ALBUMARTIST]=$artist
      notes="filled-albumartist"
    fi
  fi

  after=$(printf '%s\n' "${out[@]}" | LC_ALL=C sort)

  if [[ "$before" == "$after" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (tags ok): $flac"
    log_success "$flac" "unchanged" "" "$(file_sha256 "$flac")" "already-normalized"
    return 0
  fi

  if ((${#out[@]} == 0)); then
    # All tags stripped as junk — only rewrite if something changed
    if [[ -z "$before" ]]; then
      log_progress "skip (no tags): $flac"
      log_success "$flac" "empty" "" "$(file_sha256 "$flac")" "no-tags"
      return 0
    fi
  fi

  if ! metaflac --remove-all-tags -- "$flac"; then
    log_fail "$flac" "remove-all-tags failed"
    return 1
  fi
  for line in "${out[@]}"; do
    if ! metaflac --set-tag="$line" -- "$flac"; then
      log_fail "$flac" "set-tag failed" "tag=${line%%=*}"
      return 1
    fi
  done

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed after tag rewrite"
    return 1
  fi

  sha=$(file_sha256 "$flac")
  log_progress "normalized: $flac"
  log_success "$flac" "normalized" "" "$sha" "${notes:-ok}"
}
