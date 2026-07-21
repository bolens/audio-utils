#!/usr/bin/env bash
# Embed folder cover into audio, or extract embedded art to cover.jpg.

_art_find_cover() {
  local dir=$1 f
  f=$(LC_ALL=C find -P "$dir" -maxdepth 1 -type f \
    \( -iname 'cover.jpg' -o -iname 'cover.jpeg' -o -iname 'cover.png' \
       -o -iname 'folder.jpg' -o -iname 'folder.jpeg' -o -iname 'folder.png' \
       -o -iname 'front.jpg' -o -iname 'front.jpeg' -o -iname 'front.png' \) \
    | LC_ALL=C sort | head -n1)
  [[ -n "$f" && -s "$f" ]] || return 1
  printf '%s\n' "$f"
}

convert_one() {
  local src="$1" dir cover out tmp tagged mode

  dir=$(dirname -- "$src")

  if [[ "${ART_EXTRACT:-0}" -eq 1 ]]; then
    mode="extract"
    out="$dir/cover.jpg"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      log_progress "would extract-art: $src"; return 0
    fi
    if ! audio_has_cover "$src"; then
      log_progress "skip (no cover): $src"
      log_success "$src" "$mode" "" "$(file_sha256 "$src")" "no-picture"
      return 0
    fi
    if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      log_progress "skip (cover.jpg exists): $src"
      log_success "$src" "$mode" "" "$(file_sha256 "$src")" "cover-exists"
      return 0
    fi
    (
      flock 9
      if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then exit 0; fi
      ffmpeg -v error -y -i "$src" -an -vcodec copy "$out" 2>/dev/null \
        || ffmpeg -v error -y -i "$src" -an -c:v mjpeg "$out"
    ) 9>"$dir/.audioart.cover.lock" || {
      log_fail "$src" "export cover failed"; return 1
    }
    log_progress "extracted: $out"
    log_success "$src" "$mode" "" "$(file_sha256 "$src")" "exported"
    return 0
  fi

  mode="embed"
  if ! cover=$(_art_find_cover "$dir"); then
    log_progress "skip (no folder cover): $src"
    log_success "$src" "$mode" "" "$(file_sha256 "$src")" "no-folder-cover"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would embed: $cover → $src"; return 0
  fi
  if audio_has_cover "$src" && [[ "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (has cover): $src"
    log_success "$src" "$mode" "" "$(file_sha256 "$src")" "skipped-existing"
    return 0
  fi

  if [[ "${src,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    metaflac --remove --block-type=PICTURE --dont-use-padding -- "$src" 2>/dev/null || true
    if ! metaflac --import-picture-from="$cover" -- "$src"; then
      log_fail "$src" "import picture failed"; return 1
    fi
    log_progress "embedded: $cover → $src"
    log_success "$src" "$mode" "" "$(file_sha256 "$src")" "ok"
    return 0
  fi

  tmp=$(make_workdir "$dir")
  tagged="${tmp}/withart.${src##*.}"
  if ! ffmpeg -v error -y -i "$src" -i "$cover" \
    -map 0:a:0 -map 1:0 -c copy -c:v:0 mjpeg -disposition:v:0 attached_pic \
    "$tagged" 2>"${tmp}/err"; then
    # Fallback without disposition
    if ! ffmpeg -v error -y -i "$src" -i "$cover" \
      -map 0:a:0 -map 1:0 -c copy -disposition:v:0 attached_pic \
      "$tagged" 2>"${tmp}/err"; then
      set_last_err_file "${tmp}/err"
      log_fail "$src" "embed cover failed"
      unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
      return 1
    fi
  fi
  mv -f -- "$tagged" "$src"
  unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
  log_progress "embedded: $cover → $src"
  log_success "$src" "$mode" "" "$(file_sha256 "$src")" "ok"
}
