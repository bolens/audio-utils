#!/usr/bin/env bash
# Vorbis-comment helpers for FLAC utils (metaflac).

# First value of TAG (empty if missing). metaflac match is case-insensitive.
flac_tag_get() {
  local flac=$1 tag=$2 line
  line=$(metaflac --show-tag="$tag" -- "$flac" 2>/dev/null | head -n1)
  if [[ "$line" == *=* ]]; then
    printf '%s\n' "${line#*=}"
  else
    printf '%s\n' "$line"
  fi
}

# Trim leading/trailing whitespace (no newline in value).
flac_tag_trim() {
  local v=$1
  v=${v#"${v%%[![:space:]]*}"}
  v=${v%"${v##*[![:space:]]}"}
  printf '%s' "$v"
}

# Export all tags as TAG=value lines (stdout).
flac_tag_export() {
  metaflac --export-tags-to=- -- "$1" 2>/dev/null
}

# True if FLAC has an embedded PICTURE block.
flac_has_picture() {
  metaflac --list --block-type=PICTURE -- "$1" 2>/dev/null | grep -q 'type: 6 (PICTURE)'
}

# Zero-pad track number; preserve optional /TOTAL.
# "1" → "01", "1/12" → "01/12", "01" unchanged, "A" unchanged.
flac_tag_normalize_track() {
  local v total num
  v=$(flac_tag_trim "$1")
  [[ -n "$v" ]] || {
    printf '%s' "$v"
    return 0
  }
  if [[ "$v" == */* ]]; then
    num=${v%%/*}
    total=${v#*/}
    num=$(flac_tag_trim "$num")
    total=$(flac_tag_trim "$total")
    if [[ "$num" =~ ^[0-9]+$ ]]; then
      printf '%02d/%s' "$((10#$num))" "$total"
      return 0
    fi
    printf '%s' "$v"
    return 0
  fi
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    printf '%02d' "$((10#$v))"
    return 0
  fi
  printf '%s' "$v"
}

# Keep YYYY or YYYY-MM-DD; strip time from ISO-like values.
flac_tag_normalize_date() {
  local v
  v=$(flac_tag_trim "$1")
  [[ -n "$v" ]] || {
    printf '%s' "$v"
    return 0
  }
  if [[ "$v" =~ ^[0-9]{4}$ ]]; then
    printf '%s' "$v"
    return 0
  fi
  if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    printf '%s' "${v:0:10}"
    return 0
  fi
  if [[ "$v" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
    printf '%s' "$v"
    return 0
  fi
  printf '%s' "$v"
}

# True if TAG name looks like encoder/iTunes junk (case-insensitive).
flac_tag_is_junk() {
  local key=${1^^}
  case "$key" in
    ITUN*) return 0 ;;
    ENCODER | ENCODING | TOOL | RIPPER | ENCODEDBY | ENCODED-BY | ENCODED_BY) return 0 ;;
    WWWAUDIOFILE | WWWAUDIOSOURCE | ORIGINATOR | SOFTWARE) return 0 ;;
  esac
  return 1
}

# Sanitize a path component (reuse CUE rules when available).
flac_path_component() {
  local s=$1
  if declare -F cue_sanitize_filename >/dev/null 2>&1; then
    cue_sanitize_filename "$s"
    return 0
  fi
  s=${s//\//_}
  s=${s//$'\n'/_}
  s=$(flac_tag_trim "$s")
  [[ -n "$s" ]] || s="unknown"
  printf '%s\n' "$s"
}
