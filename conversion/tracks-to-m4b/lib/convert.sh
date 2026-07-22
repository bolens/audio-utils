#!/usr/bin/env bash
# Directory of chapter audio → one .m4b (first file claims the dir).

_t2m_list_audio() {
  local dir=$1 ext
  local -a find_args=( -P "$dir" -maxdepth 1 -type f \( )
  local first=1
  # shellcheck disable=SC2086
  for ext in ${AU_SOURCE_EXTS:-flac mp3 m4a wav}; do
    if [[ "$first" -eq 1 ]]; then
      find_args+=( -iname "*.${ext}" ); first=0
    else
      find_args+=( -o -iname "*.${ext}" )
    fi
  done
  find_args+=( \) )
  LC_ALL=C find "${find_args[@]}" | LC_ALL=C sort
}

_t2m_title_of() {
  local f=$1 t base
  t=$(audio_meta_get "$f" TITLE)
  if [[ -z "$t" ]]; then
    base=$(basename -- "$f")
    base=${base%.*}
    t=$(printf '%s' "$base" | sed -E 's/^[0-9]+[[:space:]]*[-_.]+[[:space:]]*//')
  fi
  printf '%s' "$(flac_tag_trim "$t")"
}

_t2m_build() {
  local dir=$1
  local -a files=() ff=()
  local f out tmpdir listf ffmeta dur_list cover_jpg enc_out
  local title album artist narrator series series_part genre dur sum_dur d_out
  local idx=0 sha notes codec=${M4B_CODEC:-aac} q=${M4B_QUALITY:-96}
  local escaped

  mapfile -t files < <(_t2m_list_audio "$dir")
  # Drop any .m4b sitting among chapter sources
  local -a tracks=()
  for f in "${files[@]}"; do
    case "${f,,}" in *.m4b) continue ;; esac
    tracks+=("$f")
  done
  files=("${tracks[@]}")

  if ((${#files[@]} < 1)); then
    printf 'skip-empty\n'
    return 0
  fi

  out="$(cd -- "$(dirname -- "$dir")" && pwd)/$(basename -- "$dir").m4b"

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
      -of csv=p=0 -- "$out" >/dev/null 2>&1; then
      printf 'skip-exists|%s\n' "$out"
      return 0
    fi
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry|%s|%d\n' "$out" "${#files[@]}"
    return 0
  fi

  album=$(audio_meta_get "${files[0]}" ALBUM)
  [[ -n "$album" ]] || album=$(basename -- "$dir")
  artist=$(audio_meta_get "${files[0]}" ALBUMARTIST)
  [[ -n "$artist" ]] || artist=$(audio_meta_get "${files[0]}" ARTIST)
  narrator=$(audio_meta_get "${files[0]}" NARRATOR)
  series=$(audio_meta_get "${files[0]}" SERIES)
  series_part=$(audio_meta_get "${files[0]}" SERIES-PART)
  genre=$(audio_meta_get "${files[0]}" GENRE)
  [[ -n "$genre" ]] || genre="Audiobook"
  title=$album

  tmpdir=$(make_workdir "$dir")
  listf="${tmpdir}/concat.txt"
  ffmeta="${tmpdir}/ffmeta.txt"
  dur_list="${tmpdir}/durs.txt"
  : >"$listf"
  : >"$dur_list"
  sum_dur=0

  for f in "${files[@]}"; do
    escaped=${f//\'/\'\\\'\'}
    printf "file '%s'\n" "$escaped" >>"$listf"
    dur=$(audio_duration_sec "$f") || {
      unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir"
      printf 'fail-dur\n'
      return 1
    }
    printf '%s|%s\n' "$dur" "$(_t2m_title_of "$f")" >>"$dur_list"
    sum_dur=$(awk -v a="$sum_dur" -v b="$dur" 'BEGIN { printf "%.8f", a + b }')
    ((++idx)) || true
  done

  chapters_ffmetadata_from_durations "$ffmeta" <"$dur_list"

  ff=(
    ffmpeg -v error -y -f concat -safe 0 -i "$listf"
    -i "$ffmeta"
    -map 0:a:0 -map_metadata 1 -map_chapters 1
  )
  case "$codec" in
    aac) ff+=(-codec:a aac -b:a "${q}k") ;;
    opus) ff+=(-codec:a libopus -b:a "${q}k") ;;
    alac) ff+=(-codec:a alac) ;;
  esac
  ff+=(-metadata "title=$title" -metadata "album=$album" -metadata "genre=$genre")
  [[ -n "$artist" ]] && ff+=(-metadata "album_artist=$artist" -metadata "artist=$artist")
  [[ -n "$narrator" ]] && ff+=(-metadata "narrator=$narrator")
  [[ -n "$series" ]] && ff+=(-metadata "series=$series")
  [[ -n "$series_part" ]] && ff+=(-metadata "series-part=$series_part")

  cover_jpg=""
  for f in "${files[@]}" "$dir/cover.jpg" "$dir/cover.png" "$dir/folder.jpg"; do
    [[ -e "$f" ]] || continue
    case "${f,,}" in
      *.jpg|*.jpeg|*.png)
        cover_jpg=$f
        break
        ;;
      *)
        if audio_has_cover "$f"; then
          cover_jpg="${tmpdir}/cover.jpg"
          if ! ffmpeg -v error -y -i "$f" -an -frames:v 1 "$cover_jpg" 2>/dev/null; then
            cover_jpg=""
          else
            break
          fi
        fi
        ;;
    esac
  done

  enc_out="${tmpdir}/enc.m4b"
  # Always mux as MP4 (needed for Opus-in-M4B; fine for AAC/ALAC too).
  ff+=(-f mp4)
  if ! "${ff[@]}" "$enc_out" 2>"${tmpdir}/enc.err"; then
    set_last_err_file "${tmpdir}/enc.err" 2>/dev/null || true
    unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir"
    printf 'fail-enc\n'
    return 1
  fi

  if [[ -n "$cover_jpg" && -f "$cover_jpg" ]]; then
    if ! ffmpeg -v error -y -i "$enc_out" -i "$cover_jpg" \
      -map 0 -map 1 -c copy -disposition:v:0 attached_pic -f mp4 \
      "${tmpdir}/out.m4b" 2>/dev/null; then
      mv -f -- "$enc_out" "${tmpdir}/out.m4b"
    fi
  else
    mv -f -- "$enc_out" "${tmpdir}/out.m4b"
  fi

  d_out=$(audio_duration_sec "${tmpdir}/out.m4b") || true
  if [[ -n "$d_out" ]]; then
    if ! awk -v a="$sum_dur" -v b="$d_out" 'BEGIN { d=a-b; if (d<0) d=-d; exit !(d <= 0.05) }'; then
      unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir"
      printf 'fail-duration\n'
      return 1
    fi
  fi

  mv -f -- "${tmpdir}/out.m4b" "$out"
  sha=$(file_sha256 "$out")
  notes="converted;chapters=$idx;codec=$codec"
  unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir"
  printf 'ok|%s|%s|%s\n' "$out" "$sha" "$notes"
}

convert_one() {
  local src="$1" dir key result status out sha notes n

  dir=$(cd -- "$(dirname -- "$src")" && pwd) || {
    log_fail "$src" "cannot resolve directory"
    return 1
  }

  key=$(au_sha256_str "$dir")
  if ! mkdir -- "${AU_M4B_STATE:?}/${key}.claim" 2>/dev/null; then
    log_progress "covered by dir encode: $src"
    log_success "$src" "skip" "" "" "dir-covered"
    return 0
  fi

  n=$(_t2m_list_audio "$dir" | wc -l | tr -d ' ')
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would tracks-to-m4b: $dir ($n tracks, codec=${M4B_CODEC:-aac})"
    return 0
  fi

  result=$(_t2m_build "$dir")
  status=${result%%|*}
  case "$status" in
    skip-empty)
      log_progress "skip (no tracks): $dir"
      log_success "$dir" "skip" "" "" "empty"
      return 0
      ;;
    skip-exists)
      out=${result#skip-exists|}
      log_progress "skip (m4b ok): $out"
      log_success "$dir" "$out" "" "$(file_sha256 "$out" 2>/dev/null || true)" "skipped-existing-ok"
      return 0
      ;;
    dry)
      return 0
      ;;
    fail-*)
      log_fail "$dir" "tracks-to-m4b failed" "$status"
      return 1
      ;;
    ok)
      out=$(printf '%s' "$result" | cut -d'|' -f2)
      sha=$(printf '%s' "$result" | cut -d'|' -f3)
      notes=$(printf '%s' "$result" | cut -d'|' -f4-)
      log_progress "verified: $out"
      log_success "$dir" "$out" "" "$sha" "${M4B_QUALITY:-96}" "$notes"
      return 0
      ;;
    *)
      log_fail "$dir" "tracks-to-m4b unexpected" "$result"
      return 1
      ;;
  esac
}
