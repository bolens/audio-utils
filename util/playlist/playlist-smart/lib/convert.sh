#!/usr/bin/env bash
# Match one audio file against smart-playlist filters; append hits to state.

_plsmart_match() {
  local src=$1
  local genre artist key bpm rg val

  if [[ -n "${PLSMART_GENRE}" ]]; then
    genre=$(audio_meta_get "$src" GENRE)
    [[ -n "$genre" ]] || genre=$(audio_meta_get "$src" genre)
    genre=${genre,,}
    if [[ "${genre}" != *"${PLSMART_GENRE,,}"* ]]; then
      return 1
    fi
  fi

  if [[ -n "${PLSMART_ARTIST}" ]]; then
    artist=$(audio_meta_get "$src" ARTIST)
    [[ -n "$artist" ]] || artist=$(audio_meta_get "$src" ALBUMARTIST)
    artist=${artist,,}
    if [[ "${artist}" != *"${PLSMART_ARTIST,,}"* ]]; then
      return 1
    fi
  fi

  if [[ -n "${PLSMART_KEY}" ]]; then
    key=$(audio_meta_get "$src" INITIALKEY)
    [[ -n "$key" ]] || key=$(audio_meta_get "$src" KEY)
    key=${key,,}
    key=${key// /}
    val=${PLSMART_KEY,,}
    val=${val// /}
    if [[ "$key" != "$val" ]]; then
      return 1
    fi
  fi

  if [[ -n "${PLSMART_BPM_MIN}${PLSMART_BPM_MAX}" ]]; then
    bpm=$(audio_meta_get "$src" BPM)
    [[ -n "$bpm" ]] || bpm=$(audio_meta_get "$src" TBPM)
    bpm=${bpm%%[!0-9.]*}
    if [[ -z "$bpm" ]]; then
      return 1
    fi
    if [[ -n "${PLSMART_BPM_MIN}" ]] && \
       awk -v b="$bpm" -v m="${PLSMART_BPM_MIN}" 'BEGIN { exit !(b+0 < m+0) }'; then
      return 1
    fi
    if [[ -n "${PLSMART_BPM_MAX}" ]] && \
       awk -v b="$bpm" -v m="${PLSMART_BPM_MAX}" 'BEGIN { exit !(b+0 > m+0) }'; then
      return 1
    fi
  fi

  if [[ -n "${PLSMART_RG_MAX}" ]]; then
    rg=$(audio_meta_get "$src" REPLAYGAIN_TRACK_GAIN)
    [[ -n "$rg" ]] || rg=$(audio_meta_get "$src" replaygain_track_gain)
    rg=${rg% dB}
    rg=${rg%dB}
    rg=$(flac_tag_trim "$rg")
    if [[ -z "$rg" ]]; then
      return 1
    fi
    # More negative = quieter. Fail if track gain > max (louder than wanted).
    if awk -v g="$rg" -v m="${PLSMART_RG_MAX}" 'BEGIN { exit !(g+0 > m+0) }'; then
      return 1
    fi
  fi

  return 0
}

convert_one() {
  local src="$1" abs title dur lock matches

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if _plsmart_match "$src"; then
      log_progress "would match: $src"
      log_success "$src" "match" "" "" "dry"
    else
      log_progress "no match: $src"
      log_success "$src" "skip" "" "" "no-match"
    fi
    return 0
  fi

  if ! _plsmart_match "$src"; then
    log_progress "no match: $src"
    log_success "$src" "skip" "" "" "no-match"
    return 0
  fi

  abs=$(au_abspath "$src")
  title=$(audio_meta_get "$src" TITLE)
  dur=$(audio_duration_sec "$src" 2>/dev/null || true)
  if [[ "$dur" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    dur=${dur%%.*}
  else
    dur=-1
  fi

  matches="${AU_PLSMART_STATE:?}/matches.tsv"
  lock="${AU_PLSMART_STATE}/matches.lock"
  (
    flock 9
    printf '%s\t%s\t%s\n' "$abs" "${title:-}" "$dur" >>"$matches"
  ) 9>"$lock"

  log_progress "match: $src"
  log_success "$src" "match" "" "$(file_sha256 "$src")" "queued"
}
