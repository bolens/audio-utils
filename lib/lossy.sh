#!/usr/bin/env bash
# Lossy-encode helpers: rate/channel allowlists, prepare, duration check.

# Space-separated Hz allowlists per family.
MP3_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000"
AAC_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000 64000 88200 96000"
OPUS_RATES="8000 12000 16000 24000 48000"
VORBIS_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000 88200 96000"

# True if RATE is in FAMILY allowlist (mp3|aac|opus|vorbis).
lossy_rate_ok() {
  local family="${1,,}" rate="$2" list
  case "$family" in
    mp3) list=$MP3_RATES ;;
    aac) list=$AAC_RATES ;;
    opus) list=$OPUS_RATES ;;
    vorbis) list=$VORBIS_RATES ;;
    *)
      log_err "Error: unknown lossy family '$family'"
      return 1
      ;;
  esac
  [[ -n "$rate" ]] || return 1
  case " $list " in
    *" $rate "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Lossy tools accept mono or stereo only.
lossy_channels_ok() {
  local ch="$1"
  [[ -n "$ch" ]] || return 1
  ((ch == 1 || ch == 2))
}

# Prefer 48000 for Opus; otherwise nearer of 44100/48000 to SRC rate.
lossy_target_rate() {
  local family="${1,,}" rate="${2:-0}"
  case "$family" in
    opus)
      printf '%s\n' 48000
      ;;
    *)
      if awk -v r="$rate" 'BEGIN { exit !(r != "" && (r - 44100) * (r - 44100) <= (r - 48000) * (r - 48000)) }'; then
        printf '%s\n' 44100
      else
        printf '%s\n' 48000
      fi
      ;;
  esac
}

# Duration within tol_sec (default 0.05). Args: src dest [tol]
durations_match() {
  local src="$1" dest="$2" tol="${3:-0.05}"
  local d1 d2
  d1=$(audio_duration_sec "$src") || return 1
  d2=$(audio_duration_sec "$dest") || return 1
  awk -v a="$d1" -v b="$d2" -v t="$tol" 'BEGIN {
    if (a == "" || b == "") exit 1
    diff = a - b; if (diff < 0) diff = -diff
    exit !(diff <= t)
  }'
}

# True if ffmpeg lists encoder NAME (e.g. libmp3lame, libopus).
require_ffmpeg_encoder() {
  local name="$1"
  local out
  out=$(ffmpeg -hide_banner -encoders 2>/dev/null) || true
  if [[ "$out" == *"$name"* ]]; then
    return 0
  fi
  log_err "Error: ffmpeg lacks encoder '$name' (install matching lib / ffmpeg build)."
  return 1
}

# Prepare SRC for lossy FAMILY encode.
# If rate/channels unsupported: when LOSSY_NO_RESAMPLE=1 return 1; else
# resample and/or downmix to stereo, log_note, write prep under TMPDIR.
# Prints prep path on stdout (may be SRC when already ok).
lossy_prepare_source() {
  local src="$1" tmpdir="$2" family="${3,,}"
  local ch rate need_ch=0 need_rate=0 target_rate prep err
  local -a ff_args=()

  ch=$(audio_channels "$src" || true)
  rate=$(audio_sample_rate "$src" || true)

  if ! lossy_channels_ok "$ch"; then
    need_ch=1
  fi
  if ! lossy_rate_ok "$family" "$rate"; then
    need_rate=1
  fi

  if ((need_ch == 0 && need_rate == 0)); then
    printf '%s\n' "$src"
    return 0
  fi

  if [[ "${LOSSY_NO_RESAMPLE:-0}" -eq 1 ]]; then
    AUDIO_UTILS_LAST_ERR="channels=${ch:-?} rate=${rate:-?} family=$family (LOSSY_NO_RESAMPLE=1)"
    export AUDIO_UTILS_LAST_ERR
    log_err "FAILED: unsupported rate/channels for $family (no resample): $src"
    log_err "  channels=${ch:-unknown} rate=${rate:-unknown}"
    return 1
  fi

  target_rate=$(lossy_target_rate "$family" "$rate")
  prep="$tmpdir/lossy-prep.wav"
  err="$tmpdir/lossy-prep.err"

  if ((need_ch)); then
    log_note "note: $family downmix channels=${ch:-?} → stereo: $src"
    ff_args+=(-ac 2)
  fi
  if ((need_rate)); then
    log_note "note: $family resample ${rate:-?} → ${target_rate} Hz: $src"
    ff_args+=(-ar "$target_rate")
  fi

  if ! ffmpeg -v error -y -i "$src" -map 0:a:0 "${ff_args[@]}" \
    -c:a pcm_s16le "$prep" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED lossy prepare ($family): $src"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi

  printf '%s\n' "$prep"
}
