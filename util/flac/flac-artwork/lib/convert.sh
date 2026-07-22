#!/usr/bin/env bash
# Embed folder cover into a FLAC, or extract embedded art to cover.jpg.

_art_has_picture() {
  metaflac --list --block-type=PICTURE -- "$1" 2>/dev/null | grep -q 'type: 6 (PICTURE)'
}

_art_find_cover() {
  local dir=$1
  local -a names=(
    cover.jpg cover.jpeg cover.png cover.webp
    folder.jpg folder.jpeg folder.png
    front.jpg front.jpeg front.png
    AlbumArt.jpg AlbumArt.jpeg AlbumArt.png
    albumart.jpg album.jpg
  )
  local n f
  for n in "${names[@]}"; do
    f="$dir/$n"
    if [[ -f "$f" && -s "$f" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  f=$(LC_ALL=C find -P "$dir" -maxdepth 1 -type f \
    \( -iname 'cover.jpg' -o -iname 'cover.jpeg' -o -iname 'cover.png' \
       -o -iname 'folder.jpg' -o -iname 'folder.jpeg' -o -iname 'folder.png' \
       -o -iname 'front.jpg' -o -iname 'front.jpeg' -o -iname 'front.png' \) \
    | LC_ALL=C sort | head -n1)
  [[ -n "$f" && -s "$f" ]] || return 1
  printf '%s\n' "$f"
}

_art_strip_pictures() {
  local flac=$1
  metaflac --remove --block-type=PICTURE --dont-use-padding -- "$flac" 2>/dev/null || true
}

convert_one() {
  local flac="$1"
  local dir cover out mode sha export_rc=0

  dir=$(dirname -- "$flac")

  if [[ "${ART_EXTRACT:-0}" -eq 1 ]]; then
    mode="extract"
    out="$dir/cover.jpg"

    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      log_progress "would extract-art: $flac"
      return 0
    fi

    if ! _art_has_picture "$flac"; then
      log_progress "skip (no embedded art): $flac"
      log_success "$flac" "$mode" "" "$(file_sha256 "$flac")" "no-picture"
      return 0
    fi

    if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      log_progress "skip (cover.jpg exists): $flac"
      log_success "$flac" "$mode" "" "$(file_sha256 "$flac")" "cover-exists"
      return 0
    fi

    (
      flock 9
      if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
        exit 0
      fi
      metaflac --export-picture-to="$out" -- "$flac"
    ) 9>"$dir/.flacart.cover.lock" || export_rc=$?

    if [[ "$export_rc" -ne 0 ]]; then
      log_fail "$flac" "export picture failed" "out=$out"
      return 1
    fi

    sha=$(file_sha256 "$flac")
    log_progress "extracted: $out"
    log_success "$flac" "$mode" "" "$sha" "exported"
    return 0
  fi

  mode="embed"
  if ! cover=$(_art_find_cover "$dir"); then
    log_progress "skip (no folder cover): $flac"
    log_success "$flac" "$mode" "" "$(file_sha256 "$flac")" "no-folder-cover"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would embed: $cover -> $flac"
    return 0
  fi

  if _art_has_picture "$flac" && [[ "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (has picture): $flac"
    log_success "$flac" "$mode" "" "$(file_sha256 "$flac")" "skipped-existing"
    return 0
  fi

  if _art_has_picture "$flac"; then
    _art_strip_pictures "$flac"
  fi
  if ! metaflac --import-picture-from="$cover" -- "$flac"; then
    log_fail "$flac" "import picture failed" "cover=$cover"
    return 1
  fi
  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed after embed" "cover=$cover"
    return 1
  fi

  sha=$(file_sha256 "$flac")
  log_progress "embedded: $cover -> $flac"
  log_success "$flac" "$mode" "" "$sha" "ok"
}
