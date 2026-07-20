#!/usr/bin/env bash
# Per-file FLAC → m4a

convert_one() {
  local flac="$1"
  local out="${flac%.*}.m4a"
  local dest_dir tmpdir enc_out prep md5 sha notes="" d1 d2
  local force_reconvert=0
  local quality="${LOSSY_QUALITY_NAME:-192}"

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if m4a_ok "$out"; then
      log_progress "skip (m4a ok): $out"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$out" "$(audio_md5 "$flac")" "$(file_sha256 "$out")" "$quality" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $out"
    log_info "would encode:         aac quality=$quality (${LOSSY_FF_ARGS[*]})"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$out")
  tmpdir=$(make_workdir "$dest_dir")
  enc_out="${tmpdir}/out.m4a"
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $flac (quality=$quality)"

  if ! lossy_prepare_source "$flac" "$tmpdir" "aac" >"${tmpdir}/prep.path"; then
    log_fail "$flac" "lossy prepare failed" "family=aac"
    cleanup
    return 1
  fi
  prep=$(tail -n1 "${tmpdir}/prep.path")
  [[ -f "$prep" ]] || { log_fail "$flac" "missing prep"; cleanup; return 1; }

  if ! encode_aac "$prep" "$enc_out"; then
    log_fail "$flac" "encode aac failed" "quality=$quality"
    cleanup
    return 1
  fi

  if ! m4a_ok "$enc_out"; then
    log_fail "$flac" "m4a probe failed after encode"
    cleanup
    return 1
  fi

  if ! durations_match "$prep" "$enc_out" 0.05; then
    d1=$(audio_duration_sec "$prep" || echo "?")
    d2=$(audio_duration_sec "$enc_out" || echo "?")
    log_fail "$flac" "duration mismatch (>50ms)" "src=${d1}s out=${d2}s"
    cleanup
    return 1
  fi

  mv -f -- "$enc_out" "$out"
  md5=$(audio_md5 "$flac")
  sha=$(file_sha256 "$out")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $out  quality=$quality"
  log_success "$flac" "$out" "$md5" "$sha" "$quality" "$notes"
  cleanup
}
