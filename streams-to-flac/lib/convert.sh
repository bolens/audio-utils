#!/usr/bin/env bash
# Extract each audio stream → basename.aN.flac

_audio_stream_count() {
  ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$1" 2>/dev/null | grep -c . || true
}

convert_one() {
  local src="$1"
  local base dest_dir tmpdir n i flac_out wav
  local md5_flac notes="" fail=0
  local -a enc_out

  base=$(basename -- "$src")
  base="${base%.*}"
  dest_dir=$(dirname -- "$src")
  n=$(_audio_stream_count "$src")
  n=${n:-0}

  if ((n < 1)); then
    log_fail "$src" "no audio streams"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would extract: $src ($n audio stream(s))"
    for ((i = 0; i < n; i++)); do
      log_info "  → ${base}.a${i}.flac"
    done
    return 0
  fi

  tmpdir=$(make_workdir "$dest_dir")
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "extract: $src ($n streams)"

  for ((i = 0; i < n; i++)); do
    flac_out="${dest_dir}/${base}.a${i}.flac"
    wav="${tmpdir}/a${i}.wav"

    if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      if flac_ok "$flac_out"; then
        log_progress "skip (flac ok): $flac_out"
        log_success "$src" "$flac_out" "$(audio_md5 "$flac_out")" "$(file_sha256 "$flac_out")" "skipped-existing-ok;stream=$i"
        continue
      fi
    fi

    if ! ffmpeg -v error -y -i "$src" -map "0:a:${i}" -c:a pcm_s24le "$wav" 2>"${tmpdir}/extract.err"; then
      set_last_err_file "${tmpdir}/extract.err"
      log_fail "$src" "extract stream a:$i failed"
      fail=1
      continue
    fi

    if ! encode_flac_verified "$wav" "$tmpdir" "$src#a$i" >"${tmpdir}/enc.out"; then
      log_fail "$src" "encode stream a:$i failed"
      fail=1
      continue
    fi
    mapfile -t enc_out <"${tmpdir}/enc.out"
    md5_flac=${enc_out[2]}

    # Prefer tags from that stream if possible
    if ! ffmpeg -v error -y -i "$src" -i "${enc_out[0]}" \
      -map 1:a:0 -map_metadata 0:s:a:$i -c:a copy \
      "${tmpdir}/tagged.flac" 2>"${tmpdir}/tag.err"; then
      cp -f -- "${enc_out[0]}" "${tmpdir}/tagged.flac"
    fi

    mv -f -- "${tmpdir}/tagged.flac" "$flac_out"
    notes="converted;stream=$i"
    log_info "verified: $flac_out  audio_md5=$md5_flac"
    log_success "$src" "$flac_out" "$md5_flac" "$(file_sha256 "$flac_out")" "$notes"
    rm -f -- "$wav" "${tmpdir}/pass1.flac" "${tmpdir}/pass2.flac" "${tmpdir}/roundtrip.flac" "${tmpdir}/decoded.wav" 2>/dev/null || true
  done

  if [[ "${DELETE_SOURCE:-0}" -eq 1 && "$fail" -eq 0 ]]; then
    rm -f -- "$src"
    log_info "deleted: $src"
  fi

  cleanup
  ((fail == 0))
}
