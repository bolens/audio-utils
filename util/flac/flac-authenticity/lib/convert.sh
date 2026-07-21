#!/usr/bin/env bash
# Authenticity check for one FLAC: spectral brickwall, fake hi-res, padded depth.
# Optional: mediainfo enrichment; sox/ffmpeg spectrogram PNGs beside the file.

# Measure mid (2–8 kHz) and HF highpass RMS (dB) in one ffmpeg pass.
# Sets: AUTH_MID AUTH_H16 AUTH_H18 AUTH_H20 AUTH_HX  (HX = 22 kHz or 24 kHz)
_auth_measure_bands() {
  local flac=$1 sr=$2
  local dir hx_hz fc
  local mid h16 h18 h20 hx

  AUTH_MID="" AUTH_H16="" AUTH_H18="" AUTH_H20="" AUTH_HX=""

  if ((sr >= 88200)); then
    hx_hz=24000
  else
    hx_hz=22000
  fi

  dir=$(audio_utils_mktemp_d "flacauth.XXXXXX") || return 1

  fc="[0:a]aformat=channel_layouts=mono,asplit=5[m][a][b][c][e];
[m]highpass=f=2000:poles=1,lowpass=f=8000:poles=1,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/mid:key=lavfi.astats.Overall.RMS_level[m0];
[a]highpass=f=16000:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/h16:key=lavfi.astats.Overall.RMS_level[a0];
[b]highpass=f=18000:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/h18:key=lavfi.astats.Overall.RMS_level[b0];
[c]highpass=f=20000:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/h20:key=lavfi.astats.Overall.RMS_level[c0];
[e]highpass=f=${hx_hz}:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/hx:key=lavfi.astats.Overall.RMS_level[e0]"

  if ! ffmpeg -hide_banner -nostats -i "$flac" -filter_complex "$fc" \
    -map '[m0]' -f null - \
    -map '[a0]' -f null - \
    -map '[b0]' -f null - \
    -map '[c0]' -f null - \
    -map '[e0]' -f null - \
    >/dev/null 2>&1; then
    rm -rf -- "$dir"
    return 1
  fi

  mid=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/mid")
  h16=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/h16")
  h18=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/h18")
  h20=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/h20")
  hx=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/hx")
  rm -rf -- "$dir"

  AUTH_MID=$mid
  AUTH_H16=$h16
  AUTH_H18=$h18
  AUTH_H20=$h20
  AUTH_HX=$hx
  AUTH_HX_HZ=$hx_hz
}

# Fraction of s32le samples with low 16 bits zero (padded 16-in-24/32).
# Samples ~1 MiB of left-channel PCM via -fs (avoids SIGPIPE under pipefail).
# Uses pan (not -ac 1): stereo downmix averages channels and destroys zero LSBs.
# Prints ratio 0..1.
_auth_lsb_z16_ratio() {
  local flac=$1 dir pcm ratio

  dir=$(audio_utils_mktemp_d "flacauth.XXXXXX") || { echo "0"; return 0; }
  pcm="${dir}/s32"
  if ! ffmpeg -hide_banner -nostats -y -i "$flac" -map 0:a:0 -af "pan=mono|c0=c0" \
    -f s32le -fs 1048576 "$pcm" >/dev/null 2>&1; then
    rm -rf -- "$dir"
    echo "0"
    return 0
  fi

  ratio=$(od -An -v -t u1 -- "$pcm" | awk '
    { for (i = 1; i <= NF; i++) b[n++] = $i }
    END {
      s = int(n / 4)
      if (s < 256) { print "0"; exit }
      z = 0
      for (i = 0; i < s; i++) {
        o = i * 4
        if (b[o] == 0 && b[o + 1] == 0) z++
      }
      printf "%.6f\n", z / s
    }')
  rm -rf -- "$dir"
  printf '%s\n' "${ratio:-0}"
}

# Optional mediainfo enrichment. Sets AUTH_MI_NOTE (may be empty).
_auth_mediainfo() {
  local flac=$1 sr=$2 bps=$3
  local raw mi_sr mi_bps mi_ch mi_br mi_fmt mi_dur mi_enc note=""

  AUTH_MI_NOTE=""
  [[ "${AUTH_HAVE_MEDIAINFO:-0}" -eq 1 ]] || return 0

  raw=$(mediainfo --Inform="Audio;%SamplingRate%|%BitDepth%|%Channels%|%BitRate%|%Format%|%Duration%" \
    -- "$flac" 2>/dev/null) || true
  [[ -n "$raw" ]] || return 0

  IFS='|' read -r mi_sr mi_bps mi_ch mi_br mi_fmt mi_dur <<<"$raw"
  mi_enc=$(mediainfo --Inform="General;%Encoded_Library%%Encoded_Application%" -- "$flac" 2>/dev/null || true)
  mi_enc=${mi_enc//$'\r'/}
  mi_enc=${mi_enc//$'\n'/ }
  mi_enc=${mi_enc#"${mi_enc%%[![:space:]]*}"}
  mi_enc=${mi_enc%"${mi_enc##*[![:space:]]}"}

  note="mi_sr=${mi_sr:-?};mi_bps=${mi_bps:-?};mi_ch=${mi_ch:-?};mi_br=${mi_br:-?}"
  note+=";mi_fmt=${mi_fmt:-?};mi_dur=${mi_dur:-?}"
  [[ -n "$mi_enc" ]] && note+=";mi_enc=${mi_enc}"

  if [[ -n "$mi_sr" && "$mi_sr" =~ ^[0-9]+$ && "$sr" =~ ^[0-9]+$ && "$mi_sr" != "$sr" ]]; then
    note+=";mi-mismatch-sr"
  fi
  if [[ -n "$mi_bps" && "$mi_bps" =~ ^[0-9]+$ && "$bps" =~ ^[0-9]+$ && "$bps" -gt 0 && "$mi_bps" != "$bps" ]]; then
    note+=";mi-mismatch-bps"
  fi

  AUTH_MI_NOTE=$note
}

# Write spectrogram PNG(s) beside FLAC. Appends paths to AUTH_SPEC_NOTE.
_auth_write_spectrogram() {
  local flac=$1
  local base title out_sox out_ff backend
  local wrote=()

  AUTH_SPEC_NOTE=""
  [[ "${AUTH_SPECTROGRAM:-0}" -eq 1 ]] || return 0

  base=${flac%.*}
  title=$(basename -- "$flac")
  backend=${AUTH_SPECTROGRAM_BACKEND:-ffmpeg}

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    AUTH_SPEC_NOTE="would-spectrogram=${backend}"
    log_progress "would write spectrogram (${backend}): $flac"
    return 0
  fi

  case "$backend" in
    sox|both)
      out_sox="${base}.sox.png"
      if sox "$flac" -n spectrogram -o "$out_sox" -t "$title" -x 2000 -Y 1025 -z 120 -h \
        >/dev/null 2>&1 && [[ -s "$out_sox" ]]; then
        wrote+=("$out_sox")
        log_progress "spectrogram (sox): $out_sox"
      else
        log_progress "spectrogram sox failed: $flac"
      fi
      ;;&
    ffmpeg|both)
      out_ff="${base}.ff.png"
      if ffmpeg -hide_banner -nostats -y -i "$flac" \
        -lavfi "showspectrumpic=s=1920x1024:legend=1" \
        -frames:v 1 -update 1 "$out_ff" >/dev/null 2>&1 && [[ -s "$out_ff" ]]; then
        wrote+=("$out_ff")
        log_progress "spectrogram (ffmpeg): $out_ff"
      else
        log_progress "spectrogram ffmpeg failed: $flac"
      fi
      ;;
  esac

  if ((${#wrote[@]} > 0)); then
    local IFS=,
    AUTH_SPEC_NOTE="spectrogram=${wrote[*]}"
  fi
}

# Classify measured bands. Sets AUTH_VERDICT AUTH_DETAIL (pipe-friendly notes).
_auth_classify() {
  local sr=$1 bps=$2 z16=$3
  local mid=$AUTH_MID h16=$AUTH_H16 h18=$AUTH_H18 h20=$AUTH_H20 hx=$AUTH_HX
  local strict=${AUTH_STRICT:-0}
  local cliff mid_drop up_drop dead_hf
  local thr_cliff thr_mid thr_up thr_z16
  local issues=() detail

  AUTH_VERDICT="likely-genuine"
  AUTH_DETAIL=""

  if [[ "${strict}" -eq 1 ]]; then
    thr_cliff=6.0
    thr_mid=8.0
    thr_up=5.0
    thr_z16=0.98
  else
    thr_cliff=8.0
    thr_mid=10.0
    thr_up=8.0
    thr_z16=0.995
  fi

  # Too quiet / empty spectrum → avoid crying wolf.
  if awk -v m="$mid" 'BEGIN { exit !(m < -65) }'; then
    AUTH_VERDICT="inconclusive"
    AUTH_DETAIL="mid-rms=${mid}dB (too quiet)"
    return 0
  fi

  cliff=$(awk -v a="$h16" -v b="$h20" 'BEGIN { printf "%.2f", a - b }')
  mid_drop=$(awk -v a="$mid" -v b="$h20" 'BEGIN { printf "%.2f", a - b }')
  up_drop=$(awk -v a="$mid" -v b="$hx" 'BEGIN { printf "%.2f", a - b }')

  detail="sr=${sr};bps=${bps};mid=${mid};h16=${h16};h18=${h18};h20=${h20};h${AUTH_HX_HZ}=${hx}"
  detail+=";drop16-20=${cliff};drop_mid-20=${mid_drop};drop_mid-h${AUTH_HX_HZ}=${up_drop}"

  if ((bps >= 24)); then
    detail+=";z16=${z16}"
    if awk -v z="$z16" -v t="$thr_z16" 'BEGIN { exit !(z >= t) }'; then
      issues+=("suspect-padded")
    fi
  fi

  if ((sr >= 88200)); then
    if awk -v d="$up_drop" -v t="$thr_up" 'BEGIN { exit !(d >= t) }'; then
      issues+=("suspect-upsampled")
    fi
  fi

  # Brickwall / lossy lowpass: sharp 16→20 kHz cliff + weak HF vs mid.
  # Near-dead >20 kHz with healthy mid is also a strong signal.
  dead_hf=0
  if awk -v h="$h20" -v m="$mid" 'BEGIN { exit !((h < -55) && (m > -40)) }'; then
    dead_hf=1
  fi
  if awk -v c="$cliff" -v tc="$thr_cliff" -v md="$mid_drop" -v tm="$thr_mid" \
    -v dead="$dead_hf" 'BEGIN {
      exit !((c >= tc && md >= tm) || dead == 1)
    }'; then
    issues+=("suspect-lossy")
  fi

  if ((${#issues[@]} == 0)); then
    AUTH_VERDICT="likely-genuine"
    AUTH_DETAIL=$detail
    return 0
  fi

  local IFS=';'
  AUTH_VERDICT="${issues[0]}"
  AUTH_DETAIL="${issues[*]}|${detail}"
}

_auth_append_notes() {
  local base=$1
  local extra=""
  [[ -n "${AUTH_MI_NOTE:-}" ]] && extra+=";${AUTH_MI_NOTE}"
  [[ -n "${AUTH_SPEC_NOTE:-}" ]] && extra+=";${AUTH_SPEC_NOTE}"
  printf '%s%s\n' "$base" "$extra"
}

_auth_maybe_spectrogram() {
  local flac=$1 verdict=$2
  AUTH_SPEC_NOTE=""
  [[ "${AUTH_SPECTROGRAM:-0}" -eq 1 ]] || return 0
  if [[ "${AUTH_SPECTROGRAM_ALL:-0}" -eq 1 ]] \
    || [[ "$verdict" == suspect-* ]]; then
    _auth_write_spectrogram "$flac"
  fi
}

convert_one() {
  local flac="$1"
  local sr bps z16 dur sha notes

  AUTH_MI_NOTE=""
  AUTH_SPEC_NOTE=""

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would check authenticity: $flac"
    if [[ "${AUTH_SPECTROGRAM:-0}" -eq 1 ]]; then
      _auth_write_spectrogram "$flac"
    fi
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  sr=$(audio_sample_rate "$flac") || true
  sr=${sr:-0}
  if ! [[ "$sr" =~ ^[0-9]+$ ]] || ((sr < 8000)); then
    log_fail "$flac" "could not probe sample rate"
    return 1
  fi

  bps=$(metaflac --show-bps -- "$flac" 2>/dev/null || true)
  bps=${bps:-0}
  if ! [[ "$bps" =~ ^[0-9]+$ ]]; then
    bps=0
  fi

  _auth_mediainfo "$flac" "$sr" "$bps"

  dur=$(audio_duration_sec "$flac") || true
  if [[ -n "$dur" ]] && awk -v d="$dur" 'BEGIN { exit !(d < 0.5) }'; then
    sha=$(file_sha256 "$flac")
    notes=$(_auth_append_notes "duration=${dur}s")
    log_progress "inconclusive (short): $flac"
    log_success "$flac" "inconclusive" "" "$sha" "$notes"
    return 0
  fi

  if ! _auth_measure_bands "$flac" "$sr"; then
    log_fail "$flac" "spectral measure failed" "${AUTH_MI_NOTE:-}"
    return 1
  fi

  z16="0"
  if ((bps >= 24)); then
    z16=$(_auth_lsb_z16_ratio "$flac") || z16="0"
  fi

  _auth_classify "$sr" "$bps" "$z16"
  _auth_maybe_spectrogram "$flac" "$AUTH_VERDICT"
  notes=$(_auth_append_notes "$AUTH_DETAIL")

  case "$AUTH_VERDICT" in
    likely-genuine|inconclusive)
      sha=$(file_sha256 "$flac")
      log_progress "${AUTH_VERDICT}: $flac"
      log_success "$flac" "$AUTH_VERDICT" "" "$sha" "$notes"
      return 0
      ;;
    *)
      log_fail "$flac" "$AUTH_VERDICT" "$notes"
      return 1
      ;;
  esac
}
