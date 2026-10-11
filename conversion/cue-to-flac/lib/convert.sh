#!/usr/bin/env bash
# CUE + image → per-track FLAC (serial within one cue).

_cue_tag_flac() {
  local flac_in="$1" flac_out="$2" title="$3" artist="$4" track="$5"
  local err md5_before md5_after
  local album=${6:-} album_artist=${7:-} date=${8:-} genre=${9:-}
  local -a metadata=()
  [[ -z "$album" ]] || metadata+=(-metadata "album=$album")
  [[ -z "$album_artist" ]] || metadata+=(-metadata "album_artist=$album_artist")
  [[ -z "$date" ]] || metadata+=(-metadata "date=$date")
  [[ -z "$genre" ]] || metadata+=(-metadata "genre=$genre")
  err="$(dirname -- "$flac_out")/tag.err"
  md5_before=$(audio_md5 "$flac_in")
  if ! ffmpeg -v error -y -i "$flac_in" -c copy \
    -metadata title="$title" \
    -metadata artist="$artist" \
    -metadata track="$track" "${metadata[@]}" \
    "$flac_out" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED cue tag: track=$track title=$title"
    return 1
  fi
  md5_after=$(audio_md5 "$flac_out")
  if [[ -z "$md5_before" || "$md5_before" != "$md5_after" ]]; then
    log_err "VERIFY FAIL (cue tag changed audio MD5)"
    return 1
  fi
}

convert_one() {
  local cue="$1"
  local image dest_dir tmpdir line idx title perf start_sec end_sec track_records
  local wav flac_out safe name notes="" fail=0
  local metadata_value
  local -A planned_names=()
  local -a enc_out tracks=() album_metadata=()

  if ! image=$(cue_resolve_image "$cue"); then
    log_fail "$cue" "image resolve failed"
    return 1
  fi

  if ! track_records=$(cue_list_tracks "$cue"); then
    log_fail "$cue" "cue_list_tracks failed"
    return 1
  fi
  if [[ -z "$track_records" ]]; then
    log_fail "$cue" "no tracks in CUE"
    return 1
  fi
  mapfile -t tracks <<<"$track_records"

  # Validate every planned destination before splitting any track. An image can
  # itself have a track-shaped name (or share an inode with an existing output).
  dest_dir=$(dirname -- "$cue")
  for line in "${tracks[@]}"; do
    IFS='|' read -r idx title perf start_sec end_sec <<<"$line"
    safe=$(cue_sanitize_filename "${title:-track}")
    name=$(printf '%02d - %s.flac' "$((10#$idx))" "$safe")
    if [[ -n "${planned_names[$name]:-}" ]]; then
      log_fail "$cue" "duplicate planned output: $name"
      return 1
    fi
    planned_names[$name]=1
    if [[ "${dest_dir}/${name}" -ef "$image" ]]; then
      log_fail "$cue" "output collides with CUE image: $name"
      return 1
    fi
  done

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would split: $cue (image=$(basename -- "$image"), ${#tracks[@]} tracks)"
    for line in "${tracks[@]}"; do
      IFS='|' read -r idx title perf start_sec end_sec <<<"$line"
      safe=$(cue_sanitize_filename "${title:-track}")
      name=$(printf '%02d - %s.flac' "$((10#$idx))" "$safe")
      log_info "  track $idx: $name  [${start_sec}s -> ${end_sec:-eof}]  artist=${perf:-?}"
    done
    return 0
  fi

  while IFS= read -r -d '' metadata_value; do
    album_metadata+=("$metadata_value")
  done < <(cue_album_metadata0 "$cue")

  tmpdir=$(make_workdir "$dest_dir")
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "split: $cue -> ${#tracks[@]} tracks"

  for line in "${tracks[@]}"; do
    IFS='|' read -r idx title perf start_sec end_sec <<<"$line"
    safe=$(cue_sanitize_filename "${title:-track}")
    name=$(printf '%02d - %s.flac' "$((10#$idx))" "$safe")
    flac_out="${dest_dir}/${name}"
    wav="${tmpdir}/track${idx}.wav"

    if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      if flac_ok "$flac_out"; then
        log_progress "skip (flac ok): $flac_out"
        log_success "$cue" "$flac_out" "$(audio_md5 "$flac_out")" "$(file_sha256 "$flac_out")" "skipped-existing-ok"
        continue
      fi
    fi

    if ! cue_extract_segment "$image" "$start_sec" "$end_sec" "$wav"; then
      log_fail "$cue" "extract failed track=$idx"
      fail=1
      continue
    fi

    if ! encode_flac_verified "$wav" "$tmpdir" "$cue#$idx" >"${tmpdir}/enc.out"; then
      log_fail "$cue" "encode failed track=$idx"
      fail=1
      continue
    fi
    au_mapfile0 enc_out "${tmpdir}/enc.out"

    if ! _cue_tag_flac "${enc_out[0]}" "${tmpdir}/tagged.flac" "${title:-}" "${perf:-}" "$idx" \
      "${album_metadata[0]}" "${album_metadata[1]}" "${album_metadata[2]}" "${album_metadata[3]}"; then
      log_fail "$cue" "tag failed track=$idx"
      fail=1
      continue
    fi

    if ! mv -f -- "${tmpdir}/tagged.flac" "$flac_out"; then
      log_fail "$cue" "output publication failed" "destination=$flac_out"
      fail=1
      continue
    fi
    notes="converted;track=$idx"
    log_info "verified: $flac_out  audio_md5=${enc_out[2]}"
    log_success "$cue" "$flac_out" "${enc_out[2]}" "$(file_sha256 "$flac_out")" "$notes"
    rm -f -- "$wav" "${tmpdir}/pass1.flac" "${tmpdir}/pass2.flac" "${tmpdir}/roundtrip.flac" "${tmpdir}/decoded.wav" 2>/dev/null || true
  done

  cleanup
  ((fail == 0))
}
