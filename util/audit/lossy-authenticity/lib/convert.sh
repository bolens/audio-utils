#!/usr/bin/env bash
# Detect lossy re-encodes: spectral brickwall too low for claimed bitrate.

# Measure mid (2–8 kHz) and HF band RMS. Sets LA_MID LA_H12 LA_H14 LA_H16.
_la_measure_bands() {
  local src=$1
  local dir mid h12 h14 h16
  local fc

  LA_MID="" LA_H12="" LA_H14="" LA_H16=""

  dir=$(audio_utils_mktemp_d "lossyauth.XXXXXX") || return 1

  fc="[0:a]aformat=channel_layouts=mono,asplit=4[m][a][b][c];
[m]highpass=f=2000:poles=1,lowpass=f=8000:poles=1,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/mid:key=lavfi.astats.Overall.RMS_level[m0];
[a]highpass=f=12000:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/h12:key=lavfi.astats.Overall.RMS_level[a0];
[b]highpass=f=14000:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/h14:key=lavfi.astats.Overall.RMS_level[b0];
[c]highpass=f=16000:poles=2,astats=metadata=1:reset=0,ametadata=mode=print:file=${dir}/h16:key=lavfi.astats.Overall.RMS_level[c0]"

  if ! ffmpeg -hide_banner -nostats -i "$src" -filter_complex "$fc" \
    -map '[m0]' -f null - \
    -map '[a0]' -f null - \
    -map '[b0]' -f null - \
    -map '[c0]' -f null - \
    >/dev/null 2>&1; then
    rm -rf -- "$dir"
    return 1
  fi

  mid=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/mid")
  h12=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/h12")
  h14=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/h14")
  h16=$(awk -F= '/RMS_level=/ {v=$2} END {print v+0}' "${dir}/h16")
  rm -rf -- "$dir"

  LA_MID=$mid
  LA_H12=$h12
  LA_H14=$h14
  LA_H16=$h16
}

# Expected minimum useful HF for a given kbps (lossy). Prints Hz hint band.
# Returns via LA_EXPECT: high|mid|low
_la_expect_for_kbps() {
  local kbps=$1
  if ((kbps >= 250)); then
    LA_EXPECT=high   # expect energy past ~16 kHz for honest 320
  elif ((kbps >= 160)); then
    LA_EXPECT=mid    # expect past ~14 kHz
  else
    LA_EXPECT=low    # low bitrate — brickwall OK
  fi
}

# Classify. Sets LA_VERDICT LA_DETAIL.
_la_classify() {
  local src=$1 kbps=$2 codec=$3
  local mid=$LA_MID h12=$LA_H12 h14=$LA_H14 h16=$LA_H16
  local strict=${LOSSYAUTH_STRICT:-0}
  local cliff_hi cliff_mid thr_hi thr_mid issues=() enc

  LA_VERDICT="likely-genuine"
  LA_DETAIL=""

  if [[ "${strict}" -eq 1 ]]; then
    thr_hi=10.0
    thr_mid=8.0
  else
    thr_hi=14.0
    thr_mid=12.0
  fi

  if awk -v m="$mid" 'BEGIN { exit !(m < -60) }'; then
    LA_VERDICT="inconclusive"
    LA_DETAIL="mid-rms=${mid}dB (too quiet)"
    return 0
  fi

  cliff_hi=$(awk -v a="$h12" -v b="$h16" 'BEGIN { printf "%.2f", a - b }')
  cliff_mid=$(awk -v a="$h12" -v b="$h14" 'BEGIN { printf "%.2f", a - b }')

  _la_expect_for_kbps "$kbps"

  case "$LA_EXPECT" in
    high)
      # Claimed ~320 but brickwall near 16 kHz → classic re-encode from ~128.
      if awk -v c="$cliff_hi" -v t="$thr_hi" 'BEGIN { exit !(c >= t) }' && \
         awk -v h="$h16" 'BEGIN { exit !(h < -55) }'; then
        issues+=("brickwall-vs-high-bitrate")
      fi
      ;;
    mid)
      if awk -v c="$cliff_mid" -v t="$thr_mid" 'BEGIN { exit !(c >= t) }' && \
         awk -v h="$h14" 'BEGIN { exit !(h < -55) }'; then
        issues+=("brickwall-vs-bitrate")
      fi
      ;;
    low) ;;
  esac

  enc=$(ffprobe -v error -show_entries format_tags=encoder -of default=nw=1:nk=1 -- "$src" 2>/dev/null || true)
  if [[ -n "$enc" ]]; then
    LA_DETAIL+="encoder=${enc};"
    if [[ "${enc,,}" =~ lavc|ffmpeg ]] && [[ "$codec" == mp3 || "$codec" == aac ]]; then
      # ffmpeg re-encode is common for fake high-bitrate; soft signal only in strict
      if [[ "$strict" -eq 1 ]]; then
        issues+=("ffmpeg-encoder")
      fi
    fi
  fi

  LA_DETAIL+="kbps=${kbps};codec=${codec};mid=${mid};h12=${h12};h14=${h14};h16=${h16};cliff=${cliff_hi}"

  if ((${#issues[@]} > 0)); then
    LA_VERDICT="suspect"
    local IFS='|'
    LA_DETAIL+=";${issues[*]}"
  fi
}

convert_one() {
  local src="$1" codec kbps sha

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would lossy-auth: $src"
    return 0
  fi

  codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of csv=p=0 -- "$src" 2>/dev/null) || codec=""
  if [[ -z "$codec" ]]; then
    log_fail "$src" "unreadable / no audio stream"
    return 1
  fi

  if ! kbps=$(audio_bitrate_kbps "$src"); then
    log_fail "$src" "bitrate unknown"
    return 1
  fi
  # integer kbps
  kbps=${kbps%%.*}

  if ! _la_measure_bands "$src"; then
    log_fail "$src" "spectral measure failed"
    return 1
  fi

  _la_classify "$src" "$kbps" "$codec"
  sha=$(file_sha256 "$src")

  case "$LA_VERDICT" in
    likely-genuine|inconclusive)
      log_progress "ok: $src ($LA_VERDICT)"
      log_success "$src" "$LA_VERDICT" "" "$sha" "$LA_DETAIL"
      return 0
      ;;
    *)
      log_fail "$src" "lossy authenticity $LA_VERDICT" "$LA_DETAIL"
      return 1
      ;;
  esac
}
