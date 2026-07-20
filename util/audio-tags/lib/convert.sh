#!/usr/bin/env bash
# Normalize core tags on one audio file (FLAC via metaflac; else ffmpeg remux).

convert_one() {
  local src="$1" dir tmp tagged
  local artist album title track date aa
  local track_n notes="" changed=0

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would normalize-tags: $src"
    return 0
  fi

  artist=$(audio_meta_get "$src" ARTIST)
  album=$(audio_meta_get "$src" ALBUM)
  title=$(audio_meta_get "$src" TITLE)
  track=$(audio_meta_get "$src" track)
  [[ -n "$track" ]] || track=$(audio_meta_get "$src" TRACKNUMBER)
  date=$(audio_meta_get "$src" date)
  [[ -n "$date" ]] || date=$(audio_meta_get "$src" DATE)
  aa=$(audio_meta_get "$src" album_artist)
  [[ -n "$aa" ]] || aa=$(audio_meta_get "$src" ALBUMARTIST)

  track_n=$(flac_tag_normalize_track "$track")
  date=$(flac_tag_normalize_date "$date")

  if [[ "$track_n" != "$track" && -n "$track_n" ]]; then changed=1; fi
  if [[ "${TAGS_FILL_ALBUMARTIST:-0}" -eq 1 && -n "$artist" && -z "$aa" ]]; then
    aa=$artist; changed=1; notes="filled-albumartist"
  fi

  if [[ "$changed" -eq 0 && "${OVERWRITE:-0}" -eq 0 ]]; then
    # Still uppercase FLAC keys via flac path when applicable
    if [[ "${src,,}" == *.flac ]]; then
      :
    else
      log_progress "skip (tags ok): $src"
      log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "already-normalized"
      return 0
    fi
  fi

  if [[ "${src,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    # Delegate-style: set normalized core tags
    [[ -n "$track_n" ]] && metaflac --remove-tag=TRACKNUMBER --set-tag="TRACKNUMBER=${track_n}" -- "$src"
    [[ -n "$date" ]] && metaflac --remove-tag=DATE --set-tag="DATE=${date}" -- "$src"
    if [[ -n "$aa" ]]; then
      metaflac --remove-tag=ALBUMARTIST --set-tag="ALBUMARTIST=${aa}" -- "$src"
    fi
    # Strip common junk
    local junk
    for junk in ITUNNORM ITUNSMPB ENCODER TOOL; do
      metaflac --remove-tag="$junk" -- "$src" 2>/dev/null || true
    done
    log_progress "normalized: $src"
    log_success "$src" "flac" "" "$(file_sha256 "$src")" "${notes:-ok}"
    return 0
  fi

  dir=$(dirname -- "$src")
  tmp=$(make_workdir "$dir")
  tagged="${tmp}/tagged.${src##*.}"
  local -a meta=( )
  [[ -n "$title" ]] && meta+=(-metadata "title=${title}")
  [[ -n "$artist" ]] && meta+=(-metadata "artist=${artist}")
  [[ -n "$album" ]] && meta+=(-metadata "album=${album}")
  [[ -n "$track_n" ]] && meta+=(-metadata "track=${track_n}")
  [[ -n "$date" ]] && meta+=(-metadata "date=${date}")
  [[ -n "$aa" ]] && meta+=(-metadata "album_artist=${aa}")

  if ! audio_meta_remux_tags "$src" "$tagged" "${meta[@]}"; then
    log_fail "$src" "tag remux failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  if ! mv -f -- "$tagged" "$src"; then
    log_fail "$src" "replace failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
  log_progress "normalized: $src"
  log_success "$src" "remux" "" "$(file_sha256 "$src")" "${notes:-ok}"
}
