#!/usr/bin/env bash
# Lossy-encode helpers: rate/channel allowlists, prepare, quality, encode, convert.
#
# Lossy tools set before convert:
#   LOSSY_FAMILY          mp3|aac|opus|vorbis|wma|speex|mpc
#   LOSSY_FFMPEG_ENCODER  libmp3lame|aac|libopus|libvorbis|wmav2|libspeex
#   LOSSY_DEFAULT_QUALITY (e.g. v0, 192, 128, q6)
#   LOSSY_QUALITY_ENV     primary env override (AUDIO_UTILS_MP3_QUALITY)
#   LOSSY_QUALITY_ENV_ALT tool-specific (FLAC2MP3_QUALITY)
#   AU_DEST_EXT           mp3|m4a|opus|ogg|wma|spx|mpc
# Note: mpc uses mpcenc (see flac-to-mpc), not LOSSY_FFMPEG_ENCODER.

# Space-separated Hz allowlists per family.
MP3_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000"
AAC_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000 64000 88200 96000"
OPUS_RATES="8000 12000 16000 24000 48000"
VORBIS_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000 88200 96000"
WMA_RATES="8000 11025 12000 16000 22050 24000 32000 44100 48000"
SPEEX_RATES="8000 16000 32000"
MPC_RATES="32000 37800 44100 48000"

# True if RATE is in FAMILY allowlist (mp3|aac|opus|vorbis|wma|speex|mpc).
lossy_rate_ok() {
  local family="${1,,}" rate="$2" list
  case "$family" in
    mp3) list=$MP3_RATES ;;
    aac) list=$AAC_RATES ;;
    opus) list=$OPUS_RATES ;;
    vorbis) list=$VORBIS_RATES ;;
    wma) list=$WMA_RATES ;;
    speex) list=$SPEEX_RATES ;;
    mpc) list=$MPC_RATES ;;
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

# Prefer 48000 for Opus; 16000 for Speex; otherwise nearer of 44100/48000 to SRC rate.
lossy_target_rate() {
  local family="${1,,}" rate="${2:-0}"
  case "$family" in
    opus)
      printf '%s\n' 48000
      ;;
    speex)
      printf '%s\n' 16000
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

# True if ffmpeg lists encoder NAME as its own encoder field (e.g. libmp3lame, aac).
require_ffmpeg_encoder() {
  local name="$1"
  local out
  out=$(ffmpeg -hide_banner -encoders 2>/dev/null) || true
  # Encoder lines look like: " A..... name  Description"
  # Use a here-string — printf|grep -q under pipefail SIGPIPEs on a match and
  # falsely reports the encoder as missing.
  if grep -qE "^[[:space:]]*[A-Z.]+[[:space:]]+${name}([[:space:]]|$)" <<<"$out"; then
    return 0
  fi
  log_err "Error: ffmpeg lacks encoder '$name' (install matching lib / ffmpeg build)."
  return 1
}

# Back-compat alias.
require_libmp3lame() {
  require_ffmpeg_encoder libmp3lame
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
    log_note "note: $family downmix channels=${ch:-?} -> stereo: $src"
    ff_args+=(-ac 2)
  fi
  if ((need_rate)); then
    log_note "note: $family resample ${rate:-?} -> ${target_rate} Hz: $src"
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

# --- quality profiles -------------------------------------------------------

lossy_resolve_quality() {
  local family="${LOSSY_FAMILY:?LOSSY_FAMILY required}"
  local profile="${1:-${LOSSY_DEFAULT_QUALITY:-}}"
  profile="${profile,,}"
  LOSSY_QUALITY_NAME="$profile"
  LOSSY_FF_ARGS=()

  case "$family" in
    mp3)
      case "$profile" in
        v0|vbr0) LOSSY_QUALITY_NAME=v0; LOSSY_FF_ARGS=(-codec:a libmp3lame -q:a 0) ;;
        v2|vbr2) LOSSY_QUALITY_NAME=v2; LOSSY_FF_ARGS=(-codec:a libmp3lame -q:a 2) ;;
        320|cbr320) LOSSY_QUALITY_NAME=320; LOSSY_FF_ARGS=(-codec:a libmp3lame -b:a 320k) ;;
        192|cbr192) LOSSY_QUALITY_NAME=192; LOSSY_FF_ARGS=(-codec:a libmp3lame -b:a 192k) ;;
        *)
          cat >&2 <<'EOF'
Error: unknown MP3 quality profile.

Profiles (suggested default: v0):
  v0   VBR V0  - libmp3lame -q:a 0
  v2   VBR V2  - libmp3lame -q:a 2
  320  CBR 320k
  192  CBR 192k

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2MP3_QUALITY, or AUDIO_UTILS_MP3_QUALITY
EOF
          return 1
          ;;
      esac
      ;;
    aac)
      case "$profile" in
        64|cbr64) LOSSY_QUALITY_NAME=64; LOSSY_FF_ARGS=(-codec:a aac -b:a 64k) ;;
        96|cbr96) LOSSY_QUALITY_NAME=96; LOSSY_FF_ARGS=(-codec:a aac -b:a 96k) ;;
        128|cbr128) LOSSY_QUALITY_NAME=128; LOSSY_FF_ARGS=(-codec:a aac -b:a 128k) ;;
        160|cbr160) LOSSY_QUALITY_NAME=160; LOSSY_FF_ARGS=(-codec:a aac -b:a 160k) ;;
        192|cbr192) LOSSY_QUALITY_NAME=192; LOSSY_FF_ARGS=(-codec:a aac -b:a 192k) ;;
        256|cbr256) LOSSY_QUALITY_NAME=256; LOSSY_FF_ARGS=(-codec:a aac -b:a 256k) ;;
        320|cbr320) LOSSY_QUALITY_NAME=320; LOSSY_FF_ARGS=(-codec:a aac -b:a 320k) ;;
        *)
          cat >&2 <<'EOF'
Error: unknown aac quality profile.

Profiles (default: 96):
  64 96 128 160 192 256 320  - CBR kbps via aac

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2AAC_QUALITY, or AUDIO_UTILS_AAC_QUALITY
EOF
          return 1
          ;;
      esac
      ;;
    opus)
      case "$profile" in
        64|cbr64) LOSSY_QUALITY_NAME=64; LOSSY_FF_ARGS=(-codec:a libopus -b:a 64k) ;;
        96|cbr96) LOSSY_QUALITY_NAME=96; LOSSY_FF_ARGS=(-codec:a libopus -b:a 96k) ;;
        128|cbr128) LOSSY_QUALITY_NAME=128; LOSSY_FF_ARGS=(-codec:a libopus -b:a 128k) ;;
        160|cbr160) LOSSY_QUALITY_NAME=160; LOSSY_FF_ARGS=(-codec:a libopus -b:a 160k) ;;
        192|cbr192) LOSSY_QUALITY_NAME=192; LOSSY_FF_ARGS=(-codec:a libopus -b:a 192k) ;;
        256|cbr256) LOSSY_QUALITY_NAME=256; LOSSY_FF_ARGS=(-codec:a libopus -b:a 256k) ;;
        *)
          cat >&2 <<'EOF'
Error: unknown opus quality profile.

Profiles (default: 128):
  64 96 128 160 192 256  - CBR kbps via libopus

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2OPUS_QUALITY, or AUDIO_UTILS_OPUS_QUALITY
EOF
          return 1
          ;;
      esac
      ;;
    vorbis)
      case "$profile" in
        q4|4) LOSSY_QUALITY_NAME=q4; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 4) ;;
        q5|5) LOSSY_QUALITY_NAME=q5; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 5) ;;
        q6|6) LOSSY_QUALITY_NAME=q6; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 6) ;;
        q7|7) LOSSY_QUALITY_NAME=q7; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 7) ;;
        q8|8) LOSSY_QUALITY_NAME=q8; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 8) ;;
        *)
          cat >&2 <<'EOF'
Error: unknown vorbis quality profile.

Profiles (default: q6):
  q4 q5 q6 q7 q8  - libvorbis -q:a N

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2VORBIS_QUALITY, or AUDIO_UTILS_VORBIS_QUALITY
EOF
          return 1
          ;;
      esac
      ;;
    wma)
      case "$profile" in
        128|cbr128) LOSSY_QUALITY_NAME=128; LOSSY_FF_ARGS=(-codec:a wmav2 -b:a 128k) ;;
        160|cbr160) LOSSY_QUALITY_NAME=160; LOSSY_FF_ARGS=(-codec:a wmav2 -b:a 160k) ;;
        192|cbr192) LOSSY_QUALITY_NAME=192; LOSSY_FF_ARGS=(-codec:a wmav2 -b:a 192k) ;;
        256|cbr256) LOSSY_QUALITY_NAME=256; LOSSY_FF_ARGS=(-codec:a wmav2 -b:a 256k) ;;
        *)
          cat >&2 <<'EOF'
Error: unknown wma quality profile.

Profiles (default: 192):
  128 160 192 256  - CBR kbps via wmav2

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2WMA_QUALITY, or AUDIO_UTILS_WMA_QUALITY
EOF
          return 1
          ;;
      esac
      ;;
    speex)
      case "$profile" in
        q4|4) LOSSY_QUALITY_NAME=q4; LOSSY_FF_ARGS=(-codec:a libspeex -q:a 4) ;;
        q5|5) LOSSY_QUALITY_NAME=q5; LOSSY_FF_ARGS=(-codec:a libspeex -q:a 5) ;;
        q6|6) LOSSY_QUALITY_NAME=q6; LOSSY_FF_ARGS=(-codec:a libspeex -q:a 6) ;;
        q7|7) LOSSY_QUALITY_NAME=q7; LOSSY_FF_ARGS=(-codec:a libspeex -q:a 7) ;;
        q8|8) LOSSY_QUALITY_NAME=q8; LOSSY_FF_ARGS=(-codec:a libspeex -q:a 8) ;;
        *)
          cat >&2 <<'EOF'
Error: unknown speex quality profile.

Profiles (default: q6):
  q4 q5 q6 q7 q8  - libspeex -q:a N

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2SPEEX_QUALITY, or AUDIO_UTILS_SPEEX_QUALITY
EOF
          return 1
          ;;
      esac
      ;;
    *)
      log_err "Error: unknown LOSSY_FAMILY '$family'"
      return 1
      ;;
  esac

  export LOSSY_QUALITY_NAME
  # Keep MP3_QUALITY_NAME alias for success-log / env fallbacks.
  if [[ "$family" == mp3 ]]; then
    MP3_QUALITY_NAME=$LOSSY_QUALITY_NAME
    export MP3_QUALITY_NAME
  fi
}

# Back-compat name used by older mp3 plugin code.
mp3_resolve_quality() {
  LOSSY_FAMILY=mp3 lossy_resolve_quality "$@"
}

# --- encode / probe ---------------------------------------------------------

lossy_ok() {
  local f="$1"
  [[ -f "$f" && -s "$f" ]] || return 1
  [[ -n "$(audio_codec "$f")" ]]
}

# Encode SRC → DEST using LOSSY_FF_ARGS (cover art best-effort).
lossy_encode() {
  local src="$1" dest="$2"
  local family="${LOSSY_FAMILY:-}"
  local err
  local -a extra=()
  err="$(dirname -- "$dest")/encode.err"

  if [[ "$family" == mp3 ]]; then
    extra+=(-id3v2_version 3)
  fi

  if ! ffmpeg -v error -y -i "$src" \
    -map 0:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    "${LOSSY_FF_ARGS[@]}" \
    -c:v copy \
    -disposition:v:0 attached_pic \
    "${extra[@]}" \
    "$dest" 2>"$err"; then
    if ! ffmpeg -v error -y -i "$src" \
      -map 0:a:0 -map_metadata 0 \
      "${LOSSY_FF_ARGS[@]}" \
      "${extra[@]}" \
      "$dest" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED encode ${family:-lossy}: $src -> $dest"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi
}

# --- convert pipeline -------------------------------------------------------

lossy_convert_one() {
  local flac="$1"
  local dest_ext="${AU_DEST_EXT:?AU_DEST_EXT required}"
  local family="${LOSSY_FAMILY:?LOSSY_FAMILY required}"
  local out="${flac%.*}.${dest_ext}"
  local dest_dir tmpdir enc_out prep md5 sha notes="" d1 d2
  local force_reconvert=0
  local quality="${LOSSY_QUALITY_NAME:-${LOSSY_DEFAULT_QUALITY:-}}"

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if lossy_ok "$out"; then
      log_progress "skip (${dest_ext} ok): $out"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$out" "$(audio_md5 "$flac")" "$(file_sha256 "$out")" "$quality" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $out"
    log_info "would encode:         $family quality=$quality (${LOSSY_FF_ARGS[*]})"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$out")
  tmpdir=$(make_workdir "$dest_dir")
  enc_out="${tmpdir}/out.${dest_ext}"
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $flac (quality=$quality)"

  if ! lossy_prepare_source "$flac" "$tmpdir" "$family" >"${tmpdir}/prep.path"; then
    log_fail "$flac" "lossy prepare failed" "family=$family"
    cleanup
    return 1
  fi
  prep=$(tail -n1 "${tmpdir}/prep.path")
  [[ -f "$prep" ]] || { log_fail "$flac" "missing prep"; cleanup; return 1; }

  if ! lossy_encode "$prep" "$enc_out"; then
    log_fail "$flac" "encode $family failed" "quality=$quality"
    cleanup
    return 1
  fi

  if ! lossy_ok "$enc_out"; then
    log_fail "$flac" "${dest_ext} probe failed after encode"
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
  if ((force_reconvert)); then
    notes="reconverted"
  fi
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $out  quality=$quality"
  log_success "$flac" "$out" "$md5" "$sha" "$quality" "$notes"
  cleanup
}

# --- plugin hooks -----------------------------------------------------------

lossy_plugin_consume_arg() {
  case "$1" in
    --quality)
      (($# >= 2)) || { echo "Error: --quality needs a value" >&2; exit 2; }
      QUALITY_CLI=$2
      AU_CONSUMED=2
      export AU_CONSUMED
      return 0
      ;;
    --quality=*)
      QUALITY_CLI=${1#--quality=}
      AU_CONSUMED=1
      export AU_CONSUMED
      return 0
      ;;
    --no-resample)
      LOSSY_NO_RESAMPLE=1
      AU_CONSUMED=1
      export AU_CONSUMED
      return 0
      ;;
  esac
  return 1
}

lossy_plugin_parse_opt() {
  local opt=$1 arg=${2:-}
  case "$opt" in
    Q)
      QUALITY_CLI=$arg
      return 0
      ;;
    N)
      LOSSY_NO_RESAMPLE=1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lossy_plugin_after_flags() {
  local primary="${LOSSY_QUALITY_ENV:-}"
  local alt="${LOSSY_QUALITY_ENV_ALT:-}"
  local raw="${QUALITY_CLI:-}"
  if [[ -z "$raw" && -n "$alt" ]]; then
    raw="${!alt:-}"
  fi
  if [[ -z "$raw" && -n "$primary" ]]; then
    raw="${!primary:-}"
  fi
  raw="${raw:-${LOSSY_DEFAULT_QUALITY:-}}"
  lossy_resolve_quality "$raw" || return 1
  export LOSSY_QUALITY_NAME LOSSY_NO_RESAMPLE LOSSY_FAMILY
  export LOSSY_FF_ARGS_STR="${LOSSY_FF_ARGS[*]}"
  if [[ "${LOSSY_FAMILY}" == mp3 ]]; then
    export MP3_QUALITY_NAME="$LOSSY_QUALITY_NAME"
    export MP3_FF_ARGS_STR="${LOSSY_FF_ARGS[*]}"
  fi
}

lossy_plugin_banner() {
  log_always "quality:   $LOSSY_QUALITY_NAME (${LOSSY_FF_ARGS[*]})"
  if [[ "${LOSSY_NO_RESAMPLE:-0}" -eq 1 ]]; then
    log_always "resample:  disabled (-N)"
  fi
}

lossy_plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
  export LOSSY_FAMILY LOSSY_QUALITY_NAME LOSSY_FF_ARGS_STR LOSSY_NO_RESAMPLE
  if [[ "${LOSSY_FAMILY:-}" == mp3 ]]; then
    export MP3_QUALITY_NAME MP3_FF_ARGS_STR
  fi
}

# Restore LOSSY_FF_ARGS from exported string (parallel workers).
lossy_restore_ff_args() {
  if [[ -n "${LOSSY_FF_ARGS_STR:-}" ]]; then
    # shellcheck disable=SC2206
    LOSSY_FF_ARGS=($LOSSY_FF_ARGS_STR)
  elif [[ -n "${MP3_FF_ARGS_STR:-}" ]]; then
    # shellcheck disable=SC2206
    LOSSY_FF_ARGS=($MP3_FF_ARGS_STR)
  fi
}

# Prep quality env after plugin_init; then source lib/lossy_hooks.sh at top level.
lossy_plugin_wire() {
  QUALITY_CLI="${QUALITY_CLI:-}"
  LOSSY_NO_RESAMPLE="${LOSSY_NO_RESAMPLE:-0}"
  lossy_restore_ff_args
}
