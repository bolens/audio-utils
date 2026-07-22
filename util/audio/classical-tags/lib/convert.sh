#!/usr/bin/env bash
# Normalize classical tags on one file; optionally split TITLE into WORK/MOVEMENT.

# True if genre looks classical / soundtrack / opera.
_ct_is_classical_genre() {
  local g=${1,,}
  g=$(flac_tag_trim "$g")
  case "$g" in
    classical*|classic|orchestral*|baroque*|opera*|chamber*|symphony*|concerto*| \
    soundtrack|score|ost|choral*|sacred*)
      return 0 ;;
  esac
  return 1
}

# Parse "Work: I. Allegro" / "Work - I. Allegro" / "Work / I. Allegro".
# Sets CT_WORK CT_MOVEMENT CT_MOVNUM (may be empty).
_ct_parse_title() {
  local title=$1 work mov num rest
  CT_WORK="" CT_MOVEMENT="" CT_MOVNUM=""

  title=$(flac_tag_trim "$title")
  [[ -n "$title" ]] || return 1

  # Prefer "Work: I. Movement" / "Work / 2. Movement" / "Work - III Movement"
  if [[ "$title" == *': '* ]]; then
    work=${title%%: *}
    rest=${title#*: }
  elif [[ "$title" == *' / '* ]]; then
    work=${title%% / *}
    rest=${title#* / }
  elif [[ "$title" == *' - '* ]]; then
    work=${title%% - *}
    rest=${title#* - }
  else
    return 1
  fi

  work=$(flac_tag_trim "$work")
  rest=$(flac_tag_trim "$rest")
  [[ -n "$work" && -n "$rest" ]] || return 1

  # Optional leading roman / arabic movement number ("I. Allegro", "2 - Adagio")
  if [[ "$rest" =~ ^([IVXLC]+|[0-9]+)[\.\)][[:space:]]+(.*)$ ]] || \
     [[ "$rest" =~ ^([IVXLC]+|[0-9]+)[[:space:]]+(.*)$ ]]; then
    num=${BASH_REMATCH[1]}
    mov=${BASH_REMATCH[2]}
    mov=$(flac_tag_trim "$mov")
    [[ -n "$mov" ]] || mov=$rest
  else
    num=""
    mov=$rest
  fi

  CT_WORK=$work
  CT_MOVEMENT=$mov
  CT_MOVNUM=$(flac_tag_trim "$num")
  [[ -n "$CT_WORK" && -n "$CT_MOVEMENT" ]]
}

_ct_set_flac() {
  local flac=$1
  shift
  local key val
  while (($# >= 2)); do
    key=$1; val=$2; shift 2
    metaflac --remove-tag="$key" --set-tag="${key}=${val}" -- "$flac"
  done
}

_ct_set_lossy() {
  local src=$1
  shift
  local dir tmp tagged
  local -a meta=()
  local key val
  while (($# >= 2)); do
    key=$1; val=$2; shift 2
    meta+=(-metadata "${key}=${val}")
  done
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
  local genre title composer performer conductor work movement movnum artist
  local -a planned=() issues=()
  local notes="" changed=0

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would classical-tags: $src"
    return 0
  fi

  genre=$(audio_meta_get "$src" GENRE)
  [[ -n "$genre" ]] || genre=$(audio_meta_get "$src" genre)

  if [[ "${CLASSICAL_ONLY:-1}" -eq 1 ]]; then
    if ! _ct_is_classical_genre "$genre"; then
      # Also treat presence of COMPOSER / WORK as classical even without genre.
      composer=$(audio_meta_get "$src" COMPOSER)
      work=$(audio_meta_get "$src" WORK)
      if [[ -z "$composer" && -z "$work" ]]; then
        log_progress "skip (not classical): $src"
        log_success "$src" "skip" "" "$(file_sha256 "$src")" "non-classical"
        return 0
      fi
    fi
  fi

  composer=$(audio_meta_get "$src" COMPOSER)
  performer=$(audio_meta_get "$src" PERFORMER)
  conductor=$(audio_meta_get "$src" CONDUCTOR)
  work=$(audio_meta_get "$src" WORK)
  movement=$(audio_meta_get "$src" MOVEMENT)
  movnum=$(audio_meta_get "$src" MOVEMENTNUMBER)
  [[ -n "$movnum" ]] || movnum=$(audio_meta_get "$src" MOVEMENT_NO)
  title=$(audio_meta_get "$src" TITLE)
  artist=$(audio_meta_get "$src" ARTIST)

  # Trim whitespace drift on existing role tags.
  local c_trim p_trim d_trim w_trim m_trim n_trim
  c_trim=$(flac_tag_trim "$composer")
  p_trim=$(flac_tag_trim "$performer")
  d_trim=$(flac_tag_trim "$conductor")
  w_trim=$(flac_tag_trim "$work")
  m_trim=$(flac_tag_trim "$movement")
  n_trim=$(flac_tag_trim "$movnum")

  [[ "$c_trim" == "$composer" ]] || { composer=$c_trim; planned+=("COMPOSER" "$composer"); changed=1; }
  [[ "$p_trim" == "$performer" ]] || { performer=$p_trim; planned+=("PERFORMER" "$performer"); changed=1; }
  [[ "$d_trim" == "$conductor" ]] || { conductor=$d_trim; planned+=("CONDUCTOR" "$conductor"); changed=1; }
  [[ "$w_trim" == "$work" ]] || { work=$w_trim; planned+=("WORK" "$work"); changed=1; }
  [[ "$m_trim" == "$movement" ]] || { movement=$m_trim; planned+=("MOVEMENT" "$movement"); changed=1; }
  [[ "$n_trim" == "$movnum" ]] || { movnum=$n_trim; planned+=("MOVEMENTNUMBER" "$movnum"); changed=1; }

  # Split TITLE into WORK + MOVEMENT when those tags are empty.
  if [[ -z "$work" || -z "$movement" ]] && [[ -n "$title" ]]; then
    if _ct_parse_title "$title"; then
      if [[ -z "$work" && -n "$CT_WORK" ]]; then
        work=$CT_WORK
        planned+=("WORK" "$work")
        changed=1
        notes+="split-work;"
      fi
      if [[ -z "$movement" && -n "$CT_MOVEMENT" ]]; then
        movement=$CT_MOVEMENT
        planned+=("MOVEMENT" "$movement")
        changed=1
        notes+="split-movement;"
      fi
      if [[ -z "$movnum" && -n "$CT_MOVNUM" ]]; then
        movnum=$CT_MOVNUM
        planned+=("MOVEMENTNUMBER" "$movnum")
        changed=1
        notes+="split-movnum;"
      fi
    fi
  fi

  # If COMPOSER empty but ARTIST looks like "Composer; Performer", leave alone —
  # only require when --require-roles.
  if [[ "${CLASSICAL_REQUIRE:-0}" -eq 1 && -z "$composer" ]]; then
    issues+=("missing-composer")
  fi

  # PERFORMER often equals ARTIST for classical; fill when empty.
  if [[ -z "$performer" && -n "$artist" && -n "$composer" && "$artist" != "$composer" ]]; then
    performer=$artist
    planned+=("PERFORMER" "$performer")
    changed=1
    notes+="filled-performer;"
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$src" "classical tag issues" "${issues[*]}"
    return 1
  fi

  if [[ "$changed" -eq 0 ]]; then
    log_progress "ok: $src"
    log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "already-normalized"
    return 0
  fi

  if [[ "${CLASSICAL_APPLY:-0}" -eq 0 ]]; then
    local detail="" i
    for ((i = 0; i < ${#planned[@]}; i += 2)); do
      detail+="${planned[i]}=${planned[i+1]};"
    done
    log_fail "$src" "classical tags need normalize" "${notes}${detail}"
    return 1
  fi

  if [[ "${src,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    if ! _ct_set_flac "$src" "${planned[@]}"; then
      log_fail "$src" "metaflac set failed"
      return 1
    fi
  else
    # ffmpeg metadata keys are lowercase for common tags; map WORK etc.
    local -a ffmeta=()
    local i key val
    for ((i = 0; i < ${#planned[@]}; i += 2)); do
      key=${planned[i],,}
      val=${planned[i+1]}
      ffmeta+=("$key" "$val")
    done
    if ! _ct_set_lossy "$src" "${ffmeta[@]}"; then
      log_fail "$src" "tag remux failed"
      return 1
    fi
  fi

  log_progress "normalized: $src"
  log_success "$src" "updated" "" "$(file_sha256 "$src")" "${notes:-ok}"
}
