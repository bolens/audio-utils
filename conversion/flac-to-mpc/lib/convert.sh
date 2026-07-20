#!/usr/bin/env bash
# FLAC → Musepack via mpcenc; verify duration ±50ms + probe.

convert_one() {
  local flac="$1"
  local mpc="${flac%.*}.mpc"
  local dest_dir tmpdir wav out prep
  local md5 sha notes="" d1 d2
  local force_reconvert=0
  local quality="${MPC_QUALITY:-5.0}"
  local qname="${MPC_QUALITY_NAME:-standard}"

  if [[ -f "$mpc" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if lossy_ok "$mpc"; then
      log_progress "skip (mpc ok): $mpc"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$mpc" "$(audio_md5 "$flac")" "$(file_sha256 "$mpc")" "$qname" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $mpc (quality=$qname)"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$mpc")
  tmpdir=$(make_workdir "$dest_dir")
  wav="${tmpdir}/pcm.wav"
  out="${tmpdir}/out.mpc"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac (quality=$qname)"

  # mpcenc wants WAV; prepare rate/channels like other lossy tools (stereo, 44.1/48k).
  if ! lossy_prepare_source "$flac" "$tmpdir" wma >"${tmpdir}/prep.path"; then
    log_fail "$flac" "lossy prepare failed"
    cleanup
    return 1
  fi
  prep=$(tail -n1 "${tmpdir}/prep.path")
  [[ -f "$prep" ]] || { log_fail "$flac" "missing prep"; cleanup; return 1; }

  if ! ffmpeg -v error -y -i "$prep" -map 0:a:0 -c:a pcm_s16le "$wav" 2>"${tmpdir}/wav.err"; then
    set_last_err_file "${tmpdir}/wav.err"
    log_fail "$flac" "flac→wav remux failed"
    cleanup
    return 1
  fi

  if ! mpcenc --silent --quality "$quality" "$wav" "$out" 2>"${tmpdir}/mpc.err"; then
    set_last_err_file "${tmpdir}/mpc.err"
    log_fail "$flac" "mpcenc encode failed" "quality=$qname"
    cleanup
    return 1
  fi

  if ! lossy_ok "$out"; then
    log_fail "$flac" "mpc probe failed after encode"
    cleanup
    return 1
  fi

  if ! durations_match "$wav" "$out" 0.05; then
    d1=$(audio_duration_sec "$wav" || echo "?")
    d2=$(audio_duration_sec "$out" || echo "?")
    log_fail "$flac" "duration mismatch (>50ms)" "src=${d1}s out=${d2}s"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$mpc"
  md5=$(audio_md5 "$flac")
  sha=$(file_sha256 "$mpc")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $mpc  quality=$qname"
  log_success "$flac" "$mpc" "$md5" "$sha" "$qname" "$notes"
  cleanup
}
