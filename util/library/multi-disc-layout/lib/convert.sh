#!/usr/bin/env bash
# Normalize one album's Disc N/ layout; first file claims the album unit.

_multidisc_album_dir() {
  local dir=$1 base
  base=$(basename -- "$dir")
  if [[ "${base,,}" =~ ^(disc|cd|disk)[[:space:]_-]*[0-9]+$ ]]; then
    dirname -- "$dir"
    return 0
  fi
  printf '%s\n' "$dir"
}

_multidisc_list_album_flacs() {
  local album=$1
  LC_ALL=C find -P "$album" -maxdepth 2 -type f -iname '*.flac' | LC_ALL=C sort
}

_multidisc_disc_num() {
  local flac=$1 disc
  disc=$(flac_tag_get "$flac" DISCNUMBER)
  disc=${disc%%/*}
  [[ "$disc" =~ ^[0-9]+$ ]] || disc=1
  printf '%d\n' "$((10#$disc))"
}

_multidisc_already_placed() {
  local flac=$1 album=$2 disc=$3 parent grand
  parent=$(cd -- "$(dirname -- "$flac")" && pwd) || return 1
  [[ "$(basename -- "$parent")" == "${MULTIDISC_PREFIX} ${disc}" ]] || return 1
  grand=$(cd -- "$(dirname -- "$parent")" && pwd) || return 1
  [[ "$grand" == "$album" ]]
}

_multidisc_process_album() {
  local album=$1
  local -a files=()
  local f disc tot max_disc=1 multi=0 dest dest_dir name issues=0

  mapfile -t files < <(_multidisc_list_album_flacs "$album")
  if ((${#files[@]} == 0)); then
    return 0
  fi

  for f in "${files[@]}"; do
    disc=$(_multidisc_disc_num "$f")
    ((disc > max_disc)) && max_disc=$disc
    tot=$(flac_tag_get "$f" TOTALDISCS)
    tot=${tot%%/*}
    if [[ "$tot" =~ ^[0-9]+$ ]] && ((tot > 1)); then
      multi=1
    fi
  done
  if ((max_disc > 1)); then
    multi=1
  fi

  if [[ "$multi" -eq 0 ]]; then
    log_progress "single-disc album: $album"
    return 0
  fi

  for f in "${files[@]}"; do
    disc=$(_multidisc_disc_num "$f")
    name=$(basename -- "$f")
    dest_dir="${album}/${MULTIDISC_PREFIX} ${disc}"
    dest="${dest_dir}/${name}"

    if _multidisc_already_placed "$f" "$album" "$disc"; then
      continue
    fi

    if [[ "${MULTIDISC_APPLY:-0}" -eq 0 ]]; then
      log_fail "$f" "multi-disc layout candidate" "dest=$dest disc=$disc"
      ((issues++)) || true
      continue
    fi

    if [[ ! -d "$dest_dir" ]] && ! mkdir -p -- "$dest_dir"; then
      log_fail "$f" "mkdir failed" "dir=$dest_dir"
      ((issues++)) || true
      continue
    fi

    if [[ -e "$dest" ]]; then
      local abs_f abs_d
      abs_f=$(au_abspath "$f")
      abs_d=$(au_abspath "$dest")
      if [[ "$abs_f" != "$abs_d" ]]; then
        log_fail "$f" "target exists" "dest=$dest"
        ((issues++)) || true
        continue
      fi
    fi

    if ! mv -f -- "$f" "$dest"; then
      log_fail "$f" "move failed" "dest=$dest"
      ((issues++)) || true
      continue
    fi
    log_progress "moved: $f -> $dest"
  done

  ((issues == 0))
}

convert_one() {
  local flac="$1" dir album key

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would multi-disc-layout: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  dir=$(cd -- "$(dirname -- "$flac")" && pwd) || {
    log_fail "$flac" "cannot resolve directory"
    return 1
  }
  album=$(_multidisc_album_dir "$dir")
  album=$(cd -- "$album" && pwd) || album=$dir
  key=$(au_sha256_str "$album")

  if ! mkdir -- "${AU_MULTIDISC_STATE:?}/${key}" 2>/dev/null; then
    log_progress "skip (album covered): $flac"
    log_success "$flac" "covered" "" "" "album-covered"
    return 0
  fi

  if ! _multidisc_process_album "$album"; then
    log_fail "$flac" "album layout issues" "album=$album"
    return 1
  fi

  log_progress "ok: $album"
  log_success "$flac" "album-ok" "" "$(file_sha256 "$flac")" "album=$album"
}
