#!/usr/bin/env bash
# Resample / requantize one FLAC (report or --apply in place).

_resample_sample_fmt() {
  case "${1}" in
    16) printf 's16\n' ;;
    24) printf 's32\n' ;; # ffmpeg packs 24-bit in s32 for flac
    *) return 1 ;;
  esac
}

convert_one() {
  local flac="$1" dir tmp out tagged
  local rate bits want_rate want_bits need=0 notes=""
  local af_args=() enc_args=()

  want_rate=${RESAMPLE_RATE:-}
  want_bits=${RESAMPLE_BITS:-}

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would resample: $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  rate=$(audio_sample_rate "$flac") || rate=""
  bits=$(audio_bits_per_sample "$flac") || bits=""

  if [[ -n "$want_rate" ]]; then
    if [[ -z "$rate" ]]; then
      log_fail "$flac" "cannot read sample rate"
      return 1
    fi
    if [[ "$rate" == "$want_rate" ]]; then
      :
    elif [[ "${RESAMPLE_ONLY_DOWN:-1}" -eq 1 && "$rate" -le "$want_rate" ]]; then
      notes+="skip-rate:${rate}<=${want_rate} "
    else
      need=1
      notes+="rate:${rate}→${want_rate} "
    fi
  fi

  if [[ -n "$want_bits" ]]; then
    if [[ -z "$bits" ]]; then
      log_fail "$flac" "cannot read bit depth"
      return 1
    fi
    if [[ "$bits" == "$want_bits" ]]; then
      :
    elif [[ "${RESAMPLE_ONLY_DOWN:-1}" -eq 1 && "$bits" -le "$want_bits" ]]; then
      notes+="skip-bits:${bits}<=${want_bits} "
    else
      need=1
      notes+="bits:${bits}→${want_bits} "
    fi
  fi

  notes=$(flac_tag_trim "$notes")

  if [[ "$need" -eq 0 ]]; then
    log_progress "skip (already at/under target): $flac"
    log_success "$flac" "unchanged" "" "$(file_sha256 "$flac")" "${notes:-already-ok}"
    return 0
  fi

  if [[ "${RESAMPLE_APPLY:-0}" -eq 0 ]]; then
    log_fail "$flac" "resample candidate" "$notes"
    return 1
  fi

  dir=$(dirname -- "$flac")
  tmp=$(make_workdir "$dir")
  out="${tmp}/resampled.flac"
  tagged="${tmp}/tagged.flac"

  if [[ -n "$want_rate" && "$rate" != "$want_rate" ]]; then
    if [[ "${RESAMPLE_ONLY_DOWN:-1}" -eq 0 || "$rate" -gt "$want_rate" ]]; then
      af_args+=("aresample=${want_rate}")
    fi
  fi

  enc_args=(-c:a flac)
  if [[ -n "$want_bits" ]]; then
    if [[ "${RESAMPLE_ONLY_DOWN:-1}" -eq 0 || "${bits:-99}" -gt "$want_bits" ]]; then
      local fmt
      fmt=$(_resample_sample_fmt "$want_bits") || {
        log_fail "$flac" "bad bit depth" "bits=$want_bits"
        unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
        return 1
      }
      enc_args+=(-sample_fmt "$fmt")
      # flac encoder: force bits via -compression_level and sample_fmt
      if [[ "$want_bits" == 16 ]]; then
        af_args+=("aformat=sample_fmts=s16")
      else
        af_args+=("aformat=sample_fmts=s32")
      fi
    fi
  fi

  local -a ff=(ffmpeg -v error -y -i "$flac" -map 0:a:0)
  if ((${#af_args[@]} > 0)); then
    local IFS=,
    ff+=(-af "${af_args[*]}")
  fi
  ff+=("${enc_args[@]}" "$out")

  if ! "${ff[@]}" 2>"${tmp}/enc.err"; then
    set_last_err_file "${tmp}/enc.err"
    log_fail "$flac" "resample encode failed" "$notes"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi

  if ! flac_ok "$out"; then
    log_fail "$flac" "resampled flac -t failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi

  if ! tag_flac_from_source "$flac" "$out" "$tagged"; then
    log_fail "$flac" "restore tags/cover failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi

  if ! mv -f -- "$tagged" "$flac"; then
    log_fail "$flac" "replace failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  unregister_tmpdir "$tmp"; rm -rf -- "$tmp"

  log_progress "resampled: $flac ($notes)"
  log_success "$flac" "resampled" "$(audio_md5 "$flac")" "$(file_sha256 "$flac")" "$notes"
}
