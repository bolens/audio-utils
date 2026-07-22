#!/usr/bin/env bash
# Normalize audiobook tags on one file.

_ab_is_audiobook_genre() {
  local g=${1,,}
  g=$(flac_tag_trim "$g")
  case "$g" in
    audiobook*|audio\ book*|spoken*|speech|podcast*|narrat*)
      return 0 ;;
  esac
  return 1
}

_ab_set_flac() {
  local flac=$1
  shift
  local key val
  while (($# >= 2)); do
    key=$1; val=$2; shift 2
    metaflac --remove-tag="$key" --set-tag="${key}=${val}" -- "$flac"
  done
}

_ab_set_lossy() {
  local src=$1
  shift
  local dir tmp tagged
  local -a meta=()
  local key val
  while (($# >= 2)); do
    key=$1; val=$2; shift 2
    meta+=(-metadata "${key}=${val}")
  done
  # MP4 narrator common aliases
  dir=$(dirname -- "$src")
  tmp=$(make_workdir "$dir")
  tagged="${tmp}/tagged.${src##*.}"
  if ! audio_meta_remux_tags "$src" "$tagged" "${meta[@]}"; then
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  if ! mv -f -- "$tagged" "$src"; then
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
  return 0
}

convert_one() {
  local src="$1"
  local genre title album artist aartist narrator series series_part asin isbn
  local -a planned=()
  local notes="" changed=0

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would audiobook-tags: $src"
    return 0
  fi

  genre=$(audio_meta_get "$src" GENRE)
  title=$(audio_meta_get "$src" TITLE)
  album=$(audio_meta_get "$src" ALBUM)
  artist=$(audio_meta_get "$src" ARTIST)
  aartist=$(audio_meta_get "$src" ALBUMARTIST)
  [[ -n "$aartist" ]] || aartist=$(audio_meta_get "$src" album_artist)
  narrator=$(audio_meta_get "$src" NARRATOR)
  [[ -n "$narrator" ]] || narrator=$(audio_meta_get "$src" composer)
  series=$(audio_meta_get "$src" SERIES)
  series_part=$(audio_meta_get "$src" SERIES-PART)
  [[ -n "$series_part" ]] || series_part=$(audio_meta_get "$src" SERIESPART)
  asin=$(audio_meta_get "$src" ASIN)
  isbn=$(audio_meta_get "$src" ISBN)

  if [[ "${ABOOK_ONLY:-1}" -eq 1 ]]; then
    if ! _ab_is_audiobook_genre "$genre"; then
      if [[ -z "$narrator" && -z "$series" && -z "$asin" && -z "$isbn" ]]; then
        # Single-file m4b without tags still in scope by extension.
        case "${src,,}" in
          *.m4b) ;;
          *)
            log_progress "skip (not audiobook): $src"
            log_success "$src" "skip" "" "$(file_sha256 "$src")" "non-audiobook"
            return 0
            ;;
        esac
      fi
    fi
  fi

  # Author → ALBUMARTIST; fill ARTIST if empty.
  if [[ -z "$aartist" && -n "$artist" ]]; then
    aartist=$artist
    planned+=("ALBUMARTIST" "$aartist")
    changed=1
  fi
  if [[ -n "$aartist" && -z "$artist" ]]; then
    planned+=("ARTIST" "$aartist")
    changed=1
  fi

  # Single-file book: ALBUM = book title when album empty but title set.
  case "${src,,}" in
    *.m4b)
      if [[ -z "$album" && -n "$title" ]]; then
        album=$title
        planned+=("ALBUM" "$album")
        changed=1
      fi
      if [[ -z "$title" && -n "$album" ]]; then
        title=$album
        planned+=("TITLE" "$title")
        changed=1
      fi
      ;;
  esac

  # Genre empty or spoken-word junk → Audiobook
  local g_trim
  g_trim=$(flac_tag_trim "$genre")
  if [[ -z "$g_trim" ]] || [[ "${g_trim,,}" =~ ^(spoken.?word|speech|unknown)$ ]]; then
    planned+=("GENRE" "Audiobook")
    changed=1
  fi

  # Trim narrator / series drift
  local n_trim s_trim sp_trim
  n_trim=$(flac_tag_trim "$narrator")
  s_trim=$(flac_tag_trim "$series")
  sp_trim=$(flac_tag_trim "$series_part")
  if [[ -n "$n_trim" && "$n_trim" != "$narrator" ]]; then
    planned+=("NARRATOR" "$n_trim")
    changed=1
  elif [[ -n "$n_trim" ]]; then
    # Ensure NARRATOR key exists even if we read from COMPOSER
    if [[ -z "$(audio_meta_get "$src" NARRATOR)" ]]; then
      planned+=("NARRATOR" "$n_trim")
      changed=1
    fi
  fi
  if [[ -n "$s_trim" && "$s_trim" != "$series" ]]; then
    planned+=("SERIES" "$s_trim"); changed=1
  fi
  if [[ -n "$sp_trim" ]]; then
    if [[ -z "$(audio_meta_get "$src" SERIES-PART)" ]] || [[ "$sp_trim" != "$series_part" ]]; then
      planned+=("SERIES-PART" "$sp_trim"); changed=1
    fi
  fi

  if [[ "$changed" -eq 0 ]]; then
    log_progress "ok (no changes): $src"
    log_success "$src" "clean" "" "$(file_sha256 "$src")" "unchanged"
    return 0
  fi

  notes=$(printf '%s=' "${planned[@]}" | sed 's/=$//')
  if [[ "${ABOOK_APPLY:-0}" -eq 0 ]]; then
    log_progress "would apply: $src ($notes)"
    log_success "$src" "report" "" "$(file_sha256 "$src")" "$notes"
    return 0
  fi

  if [[ "${src,,}" == *.flac ]]; then
    if ! _ab_set_flac "$src" "${planned[@]}"; then
      log_fail "$src" "metaflac tag write failed"
      return 1
    fi
  else
    if ! _ab_set_lossy "$src" "${planned[@]}"; then
      log_fail "$src" "tag remux failed"
      return 1
    fi
  fi

  log_progress "applied: $src"
  log_success "$src" "applied" "" "$(file_sha256 "$src")" "$notes"
}
