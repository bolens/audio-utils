#!/usr/bin/env bash
# Split one .m4b into per-chapter files beside the source.

_m2t_ext_for_codec() {
  case "${1,,}" in
    aac|alac|mp4a*) printf 'm4a\n' ;;
    opus) printf 'm4a\n' ;;  # prefer remux into .m4a; fallback handled by caller
    *) printf 'm4a\n' ;;
  esac
}

convert_one() {
  local src="$1"
  local dest_dir codec ext line idx start end title safe name out
  local tmpdir fail=0 n=0 copied=0
  local -a chapters=()

  case "${src,,}" in
    *.m4b) ;;
    *)
      log_fail "$src" "not an .m4b"
      return 1
      ;;
  esac

  mapfile -t chapters < <(chapters_list "$src" 2>/dev/null || true)
  if ((${#chapters[@]} == 0)); then
    log_fail "$src" "no chapters in m4b"
    return 1
  fi

  codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of csv=p=0 -- "$src" 2>/dev/null || true)
  ext=$(_m2t_ext_for_codec "$codec")

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would split: $src (${#chapters[@]} chapters, codec=${codec:-?})"
    for line in "${chapters[@]}"; do
      IFS='|' read -r idx start end title <<<"$line"
      safe=$(chapters_sanitize_filename "${title:-chapter}")
      name=$(printf '%02d - %s.%s' "$idx" "$safe" "$ext")
      log_info "  track $idx: $name  [${start}s -> ${end:-eof}]"
    done
    return 0
  fi

  dest_dir=$(dirname -- "$src")
  # Write into a sibling folder named after the book stem when many chapters
  local book_base book_dir
  book_base=$(basename -- "$src")
  book_base=${book_base%.m4b}
  book_base=${book_base%.M4B}
  book_dir="${dest_dir}/${book_base}"
  mkdir -p -- "$book_dir"

  tmpdir=$(make_workdir "$dest_dir")
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "split: $src -> ${#chapters[@]} tracks"

  for line in "${chapters[@]}"; do
    IFS='|' read -r idx start end title <<<"$line"
    safe=$(chapters_sanitize_filename "${title:-chapter}")
    name=$(printf '%02d - %s.%s' "$idx" "$safe" "$ext")
    out="${book_dir}/${name}"

    if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      if ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
        -of csv=p=0 -- "$out" >/dev/null 2>&1; then
        log_progress "skip (ok): $out"
        log_success "$src" "$out" "" "$(file_sha256 "$out")" "skipped-existing-ok"
        ((++copied)) || true
        continue
      fi
    fi

    local dur_sec
    dur_sec=""
    if [[ -n "$end" ]]; then
      dur_sec=$(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.8f", b - a }')
    fi
    local -a ff=(ffmpeg -v error -y -ss "$start" -i "$src")
    [[ -n "$dur_sec" ]] && ff+=(-t "$dur_sec")
    ff+=(-map 0:a:0 -c copy -map_metadata 0 -metadata "title=${title:-}" -metadata "track=$idx")

    if ! "${ff[@]}" "${tmpdir}/part.${ext}" 2>"${tmpdir}/err"; then
      # Opus remux to .m4a can fail on some builds — try .opus
      if [[ "${codec,,}" == opus ]]; then
        ext=opus
        name=$(printf '%02d - %s.%s' "$idx" "$safe" "$ext")
        out="${book_dir}/${name}"
        if ! "${ff[@]}" "${tmpdir}/part.${ext}" 2>"${tmpdir}/err"; then
          set_last_err_file "${tmpdir}/err" 2>/dev/null || true
          log_fail "$src" "extract failed track=$idx"
          fail=1
          continue
        fi
      else
        set_last_err_file "${tmpdir}/err" 2>/dev/null || true
        log_fail "$src" "extract failed track=$idx"
        fail=1
        continue
      fi
    fi

    mv -f -- "${tmpdir}/part.${ext}" "$out"
    log_info "wrote: $out"
    log_success "$src" "$out" "" "$(file_sha256 "$out")" "track=$idx;codec=${codec:-}"
    ((++copied)) || true
    ((++n)) || true
  done

  cleanup
  if ((fail)); then
    return 1
  fi
  log_progress "done: $src ($copied chapters -> $book_dir)"
  return 0
}
