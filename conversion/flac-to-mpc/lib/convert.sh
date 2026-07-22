#!/usr/bin/env bash
# FLAC → Musepack via mpcenc; verify duration ±50ms + probe.

# Emit mpcenc --tag args (APEv2) from FLAC Vorbis comments, one per line:
#   --tag
#   Key=value
# Read back with mapfile so keys/values keep embedded spaces.
mpc_tag_lines() {
  local flac="$1" vc ape val
  local -a map=(
    'TITLE:Title' 'ARTIST:Artist' 'ALBUM:Album' 'ALBUMARTIST:Album Artist'
    'DATE:Year' 'TRACKNUMBER:Track' 'DISCNUMBER:Disc' 'GENRE:Genre'
    'COMMENT:Comment' 'COMPOSER:Composer'
  )
  local pair
  for pair in "${map[@]}"; do
    vc=${pair%%:*}
    ape=${pair#*:}
    val=$(flac_tag_get "$flac" "$vc")
    [[ -n "$val" ]] || continue
    printf -- '--tag\n%s=%s\n' "$ape" "$val"
  done
}

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

  # mpcenc wants WAV; prepare rate/channels for the Musepack SV8 allowlist.
  if ! lossy_prepare_source "$flac" "$tmpdir" mpc >"${tmpdir}/prep.path"; then
    log_fail "$flac" "lossy prepare failed"
    cleanup
    return 1
  fi
  prep=$(tail -n1 "${tmpdir}/prep.path")
  [[ -f "$prep" ]] || { log_fail "$flac" "missing prep"; cleanup; return 1; }

  if ! ffmpeg -v error -y -i "$prep" -map 0:a:0 -c:a pcm_s16le "$wav" 2>"${tmpdir}/wav.err"; then
    set_last_err_file "${tmpdir}/wav.err"
    log_fail "$flac" "flac->wav remux failed"
    cleanup
    return 1
  fi

  # Carry tags over — mpcenc reads none from WAV input.
  local -a tag_args=()
  mapfile -t tag_args < <(mpc_tag_lines "$flac")

  # ${arr[@]+...} guards empty-array expansion under set -u on bash 4.3.
  if ! mpcenc --silent --quality "$quality" ${tag_args[@]+"${tag_args[@]}"} \
    "$wav" "$out" 2>"${tmpdir}/mpc.err"; then
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

  # ffprobe misreports SV8 stream duration (declares less than the real sample
  # count), so verify by an actual mpcdec decode instead of the declared value.
  local verify="${tmpdir}/verify.wav"
  if ! mpcdec "$out" "$verify" >/dev/null 2>"${tmpdir}/dec.err"; then
    set_last_err_file "${tmpdir}/dec.err"
    log_fail "$flac" "mpcdec verify decode failed"
    cleanup
    return 1
  fi
  if ! durations_match "$wav" "$verify" 0.05; then
    d1=$(audio_duration_sec "$wav" || echo "?")
    d2=$(audio_duration_sec "$verify" || echo "?")
    log_fail "$flac" "duration mismatch after decode (>50ms)" "src=${d1}s decoded=${d2}s"
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
