#!/usr/bin/env bash
# Once per album directory: concat FLACs → image.flac + matching CUE.

_cueexp_dir_key() {
  au_sha256_str "$1"
}

_cueexp_list_flacs() {
  LC_ALL=C find -P "$1" -maxdepth 1 -type f -iname '*.flac' | LC_ALL=C sort
}

_cueexp_sec_to_msf() {
  awk -v s="$1" 'BEGIN {
    if (s < 0) s = 0
    frames = int(s * 75 + 0.5)
    ff = frames % 75
    ss = int(frames / 75) % 60
    mm = int(frames / 75 / 60)
    printf "%02d:%02d:%02d\n", mm, ss, ff
  }'
}

_cueexp_quote() {
  local s=$1
  s=${s//\"/\'}
  printf '"%s"' "$s"
}

_cueexp_build_album() {
  local dir=$1
  local done_f=$2
  local -a flacs=()
  local album artist date genre base image cue listf tmpdir
  local f idx dur offset rate0 rate ch0 ch title perf
  local md5 sha

  if [[ -f "$done_f" ]]; then
    return 0
  fi

  mapfile -t flacs < <(_cueexp_list_flacs "$dir")
  if ((${#flacs[@]} < 2)); then
    printf 'skip-lt2\n' >"$done_f"
    return 0
  fi

  album=$(flac_tag_trim "$(flac_tag_get "${flacs[0]}" ALBUM)")
  artist=$(flac_tag_trim "$(flac_tag_get "${flacs[0]}" ALBUMARTIST)")
  [[ -n "$artist" ]] || artist=$(flac_tag_trim "$(flac_tag_get "${flacs[0]}" ARTIST)")
  date=$(flac_tag_normalize_date "$(flac_tag_get "${flacs[0]}" DATE)")
  genre=$(flac_tag_trim "$(flac_tag_get "${flacs[0]}" GENRE)")
  [[ -n "$album" ]] || album=$(basename -- "$dir")
  [[ -n "$artist" ]] || artist="Unknown Artist"

  base=$(flac_path_component "$album")
  image="${dir}/${base}.flac"
  cue="${dir}/${base}.cue"

  # Skip if outputs already look like our image (same basename as album)
  # Don't include image.flac itself in the track list if re-running.
  local -a tracks=()
  for f in "${flacs[@]}"; do
    if [[ "$(au_abspath "$f")" == \
          "$(au_abspath "$image")" ]]; then
      continue
    fi
    tracks+=("$f")
  done
  if ((${#tracks[@]} < 2)); then
    printf 'skip-lt2\n' >"$done_f"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry\n' >"$done_f"
    return 0
  fi

  if [[ -f "$image" || -f "$cue" ]] && [[ "${OVERWRITE:-0}" -eq 0 ]]; then
    printf 'exists\n' >"$done_f"
    return 0
  fi

  rate0=$(audio_sample_rate "${tracks[0]}") || true
  ch0=$(audio_channels "${tracks[0]}") || true
  for f in "${tracks[@]}"; do
    rate=$(audio_sample_rate "$f") || true
    ch=$(audio_channels "$f") || true
    if [[ -n "$rate0" && -n "$rate" && "$rate" != "$rate0" ]]; then
      printf 'fail-rate\n' >"$done_f"
      return 1
    fi
    if [[ -n "$ch0" && -n "$ch" && "$ch" != "$ch0" ]]; then
      printf 'fail-ch\n' >"$done_f"
      return 1
    fi
  done

  tmpdir=$(make_workdir "$dir")
  listf="${tmpdir}/concat.txt"
  : >"$listf"
  for f in "${tracks[@]}"; do
    # ffmpeg concat demuxer needs escaped single quotes
    local esc=${f//\'/\'\\\'\'}
    printf "file '%s'\n" "$esc" >>"$listf"
  done

  if ! ffmpeg -v error -y -f concat -safe 0 -i "$listf" -c:a flac \
    "${tmpdir}/image.flac" 2>"${tmpdir}/enc.err"; then
    set_last_err_file "${tmpdir}/enc.err"
    printf 'fail-enc\n' >"$done_f"
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir"
    return 1
  fi

  # Build CUE
  {
    printf 'REM GENRE %s\n' "$(_cueexp_quote "${genre:-Unknown}")"
    if [[ -n "$date" ]]; then
      printf 'REM DATE %s\n' "$date"
    fi
    printf 'PERFORMER %s\n' "$(_cueexp_quote "$artist")"
    printf 'TITLE %s\n' "$(_cueexp_quote "$album")"
    printf 'FILE %s WAVE\n' "$(_cueexp_quote "$(basename -- "$image")")"
    offset=0
    idx=1
    for f in "${tracks[@]}"; do
      title=$(flac_tag_trim "$(flac_tag_get "$f" TITLE)")
      [[ -n "$title" ]] || title=$(basename -- "${f%.*}")
      perf=$(flac_tag_trim "$(flac_tag_get "$f" ARTIST)")
      [[ -n "$perf" ]] || perf=$artist
      printf '  TRACK %02d AUDIO\n' "$idx"
      printf '    TITLE %s\n' "$(_cueexp_quote "$title")"
      printf '    PERFORMER %s\n' "$(_cueexp_quote "$perf")"
      printf '    INDEX 01 %s\n' "$(_cueexp_sec_to_msf "$offset")"
      dur=$(audio_duration_sec "$f") || dur=0
      offset=$(awk -v a="$offset" -v b="${dur:-0}" 'BEGIN { printf "%.8f\n", a + b }')
      ((idx++)) || true
    done
  } >"${tmpdir}/album.cue"

  if ! flac_ok "${tmpdir}/image.flac"; then
    printf 'fail-test\n' >"$done_f"
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir"
    return 1
  fi

  mv -f -- "${tmpdir}/image.flac" "$image"
  mv -f -- "${tmpdir}/album.cue" "$cue"
  unregister_tmpdir "$tmpdir"
  rm -rf -- "$tmpdir"

  md5=$(metaflac --show-md5sum -- "$image" 2>/dev/null || true)
  sha=$(file_sha256 "$image")
  printf 'ok\t%s\t%s\t%s\n' "$image" "$md5" "$sha" >"$done_f"
  return 0
}

convert_one() {
  local flac="$1"
  local dir key lock done_f state image md5 sha rc=0

  dir=$(dirname -- "$flac")
  key=$(_cueexp_dir_key "$dir")
  lock="${AU_CUEEXP_STATE:?}/$key.lock"
  done_f="${AU_CUEEXP_STATE}/$key.done"

  (
    flock 9
    _cueexp_build_album "$dir" "$done_f"
  ) 9>"$lock" || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    log_fail "$flac" "cue-export failed" "dir=$dir"
    return 1
  fi

  state=$(head -n1 -- "$done_f" 2>/dev/null || true)
  case "$state" in
    dry)
      log_progress "would cue-export: $dir"
      return 0
      ;;
    skip-lt2)
      log_progress "skip (<2 tracks): $dir"
      log_success "$flac" "skipped" "" "$(file_sha256 "$flac")" "lt2-tracks"
      return 0
      ;;
    exists)
      log_progress "skip (image/cue exists): $dir"
      log_success "$flac" "skipped" "" "$(file_sha256 "$flac")" "exists"
      return 0
      ;;
    ok*)
      IFS=$'\t' read -r _ image md5 sha <<<"$state" || true
      log_progress "cue-export: $image"
      log_success "$flac" "exported" "${md5:-}" "${sha:-}" "image=$(basename -- "${image:-}")"
      return 0
      ;;
    fail-*)
      log_fail "$flac" "cue-export failed" "state=$state dir=$dir"
      return 1
      ;;
    *)
      log_fail "$flac" "cue-export unknown state" "state=$state"
      return 1
      ;;
  esac
}
