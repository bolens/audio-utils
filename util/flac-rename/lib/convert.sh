#!/usr/bin/env bash
# Rename one FLAC from tags (inplace or Artist/Album layout).

_rename_target() {
  local flac=$1
  local artist album title track dir dest_dir name dest

  artist=$(flac_tag_get "$flac" ARTIST)
  artist=$(flac_tag_trim "$artist")
  [[ -n "$artist" ]] || artist=$(flac_tag_trim "$(flac_tag_get "$flac" ALBUMARTIST)")
  album=$(flac_tag_trim "$(flac_tag_get "$flac" ALBUM)")
  title=$(flac_tag_trim "$(flac_tag_get "$flac" TITLE)")
  track=$(flac_tag_normalize_track "$(flac_tag_get "$flac" TRACKNUMBER)")
  track=${track%%/*}

  [[ -n "$title" ]] || title=$(basename -- "${flac%.*}")
  [[ -n "$track" && "$track" =~ ^[0-9]+$ ]] || track="00"

  name=$(printf '%02d - %s.flac' "$((10#$track))" "$(flac_path_component "$title")")

  dir=$(dirname -- "$flac")
  case "${RENAME_LAYOUT:-inplace}" in
    inplace)
      dest_dir=$dir
      ;;
    artist-album)
      [[ -n "$artist" ]] || artist="Unknown Artist"
      [[ -n "$album" ]] || album="Unknown Album"
      dest_dir="${RENAME_DEST_ROOT}/$(flac_path_component "$artist")/$(flac_path_component "$album")"
      ;;
    *)
      return 1
      ;;
  esac

  dest="${dest_dir}/${name}"
  printf '%s\n' "$dest"
}

convert_one() {
  local flac="$1"
  local dest abs_src abs_dest dest_dir sha

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if dest=$(_rename_target "$flac"); then
      log_progress "would rename: $flac → $dest"
    else
      log_progress "would rename: $flac (target unresolved)"
    fi
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  if ! dest=$(_rename_target "$flac"); then
    log_fail "$flac" "could not build target path"
    return 1
  fi

  abs_src=$(au_abspath "$flac")
  abs_dest=$(au_abspath "$dest")
  # If dest doesn't exist yet, resolve parent + basename
  if [[ ! -e "$dest" ]]; then
    dest_dir=$(dirname -- "$dest")
    abs_dest="$(cd -- "$dest_dir" 2>/dev/null && pwd)/$(basename -- "$dest")" || abs_dest=$dest
  fi

  if [[ "$abs_src" == "$abs_dest" ]]; then
    log_progress "skip (name ok): $flac"
    log_success "$flac" "$dest" "" "$(file_sha256 "$flac")" "already-named"
    return 0
  fi

  dest_dir=$(dirname -- "$dest")
  if [[ ! -d "$dest_dir" ]]; then
    if ! mkdir -p -- "$dest_dir"; then
      log_fail "$flac" "mkdir failed" "dir=$dest_dir"
      return 1
    fi
  fi

  if [[ -e "$dest" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_fail "$flac" "target exists" "dest=$dest"
    return 1
  fi

  if ! mv -f -- "$flac" "$dest"; then
    log_fail "$flac" "rename failed" "dest=$dest"
    return 1
  fi

  sha=$(file_sha256 "$dest")
  log_progress "renamed: $flac → $dest"
  log_success "$flac" "$dest" "" "$sha" "ok"
}
