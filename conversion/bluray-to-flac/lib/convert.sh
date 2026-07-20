#!/usr/bin/env bash
# BDMV / device / decrypted m2ts|mkv → per-stream FLAC

_extract_media_streams() {
  local src="$1" outdir="$2" tmpdir="$3"
  local base n i wav flac_out
  local -a enc_out
  local fail=0

  base=$(basename -- "$src")
  base="${base%.*}"
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$src" 2>/dev/null | grep -c . || true)
  n=${n:-0}
  ((n >= 1)) || {
    log_fail "$src" "no audio streams"
    return 1
  }

  for ((i = 0; i < n; i++)); do
    flac_out="${outdir}/${base}.a${i}.flac"
    wav="${tmpdir}/${base}.a${i}.wav"

    if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]] && flac_ok "$flac_out"; then
      log_progress "skip (flac ok): $flac_out"
      log_success "$src" "$flac_out" "$(audio_md5 "$flac_out")" "$(file_sha256 "$flac_out")" "skipped-existing-ok;stream=$i"
      continue
    fi

    if ! ffmpeg -v error -y -i "$src" -map "0:a:${i}" -c:a pcm_s24le "$wav" 2>"${tmpdir}/ex.err"; then
      set_last_err_file "${tmpdir}/ex.err"
      log_fail "$src" "extract a:$i failed"
      fail=1
      continue
    fi
    if ! encode_flac_verified "$wav" "$tmpdir" "$src#a$i" >"${tmpdir}/enc.out"; then
      log_fail "$src" "encode a:$i failed"
      fail=1
      continue
    fi
    mapfile -t enc_out <"${tmpdir}/enc.out"
    mv -f -- "${enc_out[0]}" "$flac_out"
    log_info "verified: $flac_out"
    log_success "$src" "$flac_out" "${enc_out[2]}" "$(file_sha256 "$flac_out")" "converted;stream=$i"
    rm -f -- "$wav" \
      "${tmpdir}/pass1.flac" "${tmpdir}/pass2.flac" "${tmpdir}/pass3.flac" \
      "${tmpdir}/roundtrip.flac" "${tmpdir}/decoded.wav" "${tmpdir}/enc.out" 2>/dev/null || true
  done
  return "$fail"
}

convert_one() {
  local path="$1"
  local outdir tmpdir work media fail=0 kind disc_label

  kind=$(bluray_resolve_input "$path" 2>/dev/null) || kind=unknown
  if [[ "$kind" == unknown ]]; then
    log_fail "$path" "not a BDMV tree, device, or decrypted media"
    return 1
  fi

  case "$kind" in
    bdmv)
      disc_label=$(bluray_disc_root "$path" 2>/dev/null || printf '%s' "$path")
      outdir="${disc_label}/flac"
      ;;
    media_file)
      outdir="$(dirname -- "$path")"
      ;;
    media_dir)
      outdir="${path}/flac"
      ;;
    device)
      outdir="${PWD}/bluray-rip"
      ;;
    *)
      outdir="${PWD}/bluray-rip"
      ;;
  esac

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would extract Blu-ray audio: $path → $outdir/ (kind=$kind)"
    return 0
  fi

  mkdir -p -- "$outdir" || return 1
  tmpdir=$(make_workdir "$outdir")
  work="${tmpdir}/media"
  mkdir -p -- "$work"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "bluray extract: $path (kind=$kind)"

  if ! bluray_decrypt_or_copy "$path" "$work" >"${tmpdir}/media.list"; then
    log_fail "$path" "decrypt/passthrough failed"
    cleanup
    return 1
  fi
  mapfile -t media <"${tmpdir}/media.list"
  if ((${#media[@]} == 0)); then
    log_fail "$path" "no readable media after resolve"
    cleanup
    return 1
  fi

  for f in "${media[@]}"; do
    [[ -n "$f" ]] || continue
    if ! _extract_media_streams "$f" "$outdir" "$tmpdir"; then
      fail=1
    fi
  done

  cleanup
  ((fail == 0))
}
