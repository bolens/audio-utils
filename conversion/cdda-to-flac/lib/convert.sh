#!/usr/bin/env bash
# Rip one CDDA track: convert_one receives "DEVICE/TRACK" synthetic path.

convert_one() {
  local syn="$1"
  local device tracknum outdir tmpdir wav flac_out
  local md5_flac notes=""
  local -a enc_out

  # Synthetic: /dev/sr0/3 or DEVICE#3
  if [[ "$syn" == *"#"* ]]; then
    device=${syn%#*}
    tracknum=${syn##*#}
  else
    device=$(dirname -- "$syn")
    tracknum=$(basename -- "$syn")
  fi

  outdir="${CDDA_OUTDIR:-.}"
  flac_out=$(printf '%s/track%02d.flac' "$outdir" "$((10#$tracknum))")

  if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]] && flac_ok "$flac_out"; then
    log_progress "skip (flac ok): $flac_out"
    if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
      log_success "$syn" "$flac_out" "$(audio_md5 "$flac_out")" "$(file_sha256 "$flac_out")" "skipped-existing-ok"
    fi
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would rip: device=$device track=$tracknum → $flac_out"
    return 0
  fi

  mkdir -p -- "$outdir"
  tmpdir=$(make_workdir "$outdir")
  wav="${tmpdir}/track${tracknum}.wav"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "rip: $device track $tracknum"
  if ! cdda_rip_track "$device" "$tracknum" "$wav"; then
    log_fail "$syn" "cdparanoia rip failed"
    cleanup
    return 1
  fi

  if ! encode_flac_verified "$wav" "$tmpdir" "$syn" >"${tmpdir}/enc.out"; then
    log_fail "$syn" "encode/verify failed"
    cleanup
    return 1
  fi
  mapfile -t enc_out <"${tmpdir}/enc.out"
  md5_flac=${enc_out[2]}

  # Tag track number
  if ! ffmpeg -v error -y -i "${enc_out[0]}" -c copy \
    -metadata track="$tracknum" \
    "${tmpdir}/tagged.flac" 2>"${tmpdir}/tag.err"; then
    cp -f -- "${enc_out[0]}" "${tmpdir}/tagged.flac"
  fi

  mv -f -- "${tmpdir}/tagged.flac" "$flac_out"
  notes="ripped;track=$tracknum"
  log_info "verified: $flac_out  audio_md5=$md5_flac"
  log_success "$syn" "$flac_out" "$md5_flac" "$(file_sha256 "$flac_out")" "$notes"
  cleanup
}
