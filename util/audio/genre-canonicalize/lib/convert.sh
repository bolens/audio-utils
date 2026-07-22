#!/usr/bin/env bash
# Canonicalize GENRE on one audio file.

# Print canonical genre for KEY (lowercase); empty if unknown.
_genre_builtin_lookup() {
  local key=$1
  case "$key" in
    rock|classic\ rock|hard\ rock|prog\ rock|progressive\ rock) printf 'Rock\n' ;;
    metal|heavy\ metal|death\ metal|black\ metal|thrash\ metal) printf 'Metal\n' ;;
    punk|punk\ rock|post-punk|post\ punk) printf 'Punk\n' ;;
    indie|indie\ rock|alternative|alt\ rock|alternative\ rock) printf 'Indie\n' ;;
    pop|synth-pop|synthpop|electropop) printf 'Pop\n' ;;
    electronic|electronica|edm|dance|techno|house|trance|ambient) printf 'Electronic\n' ;;
    hip-hop|hip\ hop|hiphop|rap) printf 'Hip-Hop\n' ;;
    'r&b'|rnb|'r & b'|rhythm\ and\ blues) printf 'R&B\n' ;;
    jazz|bebop|be-bop|fusion) printf 'Jazz\n' ;;
    blues) printf 'Blues\n' ;;
    country|americana|alt-country|alt\ country) printf 'Country\n' ;;
    folk|folk\ rock|singer-songwriter|singer\ songwriter) printf 'Folk\n' ;;
    classical|classic|orchestral|baroque|opera) printf 'Classical\n' ;;
    soundtrack|score|ost) printf 'Soundtrack\n' ;;
    reggae|ska|dub) printf 'Reggae\n' ;;
    soul|funk|disco) printf 'Soul\n' ;;
    world|world\ music|latin|afrobeat) printf 'World\n' ;;
    spoken\ word|audiobook|podcast|speech) printf 'Spoken\n' ;;
    experimental|avant-garde|avant\ garde|noise) printf 'Experimental\n' ;;
    *) return 1 ;;
  esac
}

# Load optional map file into GENRE_MAP_ASSOC via temp files (bash 4 assoc).
# Format: alias<TAB>Canonical   or alias=Canonical  (# comments, blank ok)
_genre_map_lookup() {
  local key=$1 line alias canon
  local map=${GENRE_MAP_FILE:-}

  if [[ -n "$map" && -f "$map" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      if [[ "$line" == *$'\t'* ]]; then
        alias=${line%%$'\t'*}
        canon=${line#*$'\t'}
      elif [[ "$line" == *'='* ]]; then
        alias=${line%%=*}
        canon=${line#*=}
      else
        continue
      fi
      alias=$(flac_tag_trim "${alias,,}")
      canon=$(flac_tag_trim "$canon")
      if [[ "$alias" == "$key" && -n "$canon" ]]; then
        printf '%s\n' "$canon"
        return 0
      fi
    done <"$map"
  fi
  _genre_builtin_lookup "$key"
}

_genre_set_flac() {
  local flac=$1 genre=$2
  metaflac --remove-tag=GENRE --set-tag="GENRE=${genre}" -- "$flac"
}

_genre_set_lossy() {
  local src=$1 genre=$2 dir tmp tagged
  dir=$(dirname -- "$src")
  tmp=$(make_workdir "$dir")
  tagged="${tmp}/tagged.${src##*.}"
  if ! audio_meta_remux_tags "$src" "$tagged" -metadata "genre=${genre}"; then
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
  local src="$1" raw key canon

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would genre-canonicalize: $src"
    return 0
  fi

  raw=$(audio_meta_get "$src" GENRE)
  [[ -n "$raw" ]] || raw=$(audio_meta_get "$src" genre)

  if [[ -z "$raw" ]]; then
    log_progress "skip (no genre): $src"
    log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "no-genre"
    return 0
  fi

  # Use first genre if multi-valued (semicolon / slash)
  raw=${raw%%;*}
  raw=${raw%%/*}
  raw=$(flac_tag_trim "$raw")
  key=${raw,,}

  if ! canon=$(_genre_map_lookup "$key"); then
    log_fail "$src" "unmapped genre" "genre=$raw"
    return 1
  fi

  if [[ "$raw" == "$canon" ]]; then
    log_progress "ok: $src ($canon)"
    log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "already-canonical"
    return 0
  fi

  if [[ "${GENRE_APPLY:-0}" -eq 0 ]]; then
    log_fail "$src" "genre not canonical" "from=$raw to=$canon"
    return 1
  fi

  if [[ "${src,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    if ! _genre_set_flac "$src" "$canon"; then
      log_fail "$src" "metaflac genre set failed"
      return 1
    fi
  else
    if ! _genre_set_lossy "$src" "$canon"; then
      log_fail "$src" "genre remux failed"
      return 1
    fi
  fi

  log_progress "canonicalized: $src ($raw → $canon)"
  log_success "$src" "updated" "" "$(file_sha256 "$src")" "$raw→$canon"
}
