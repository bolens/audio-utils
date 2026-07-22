#!/usr/bin/env bash
# Takc (TAK encoder/decoder) resolution and wrappers (native or Wine).

# Validate preset: p0–p5 with optional e/m suffix (e.g. p2, p3e, p4m).
takc_preset_ok() {
  local p="${1,,}"
  [[ "$p" =~ ^p[0-5][em]?$ ]]
}

# Populate TAKC_CMD array: native binary or (wine path-to-Takc.exe).
takc_resolve() {
  local bin=""
  TAKC_CMD=()

  if [[ -n "${AUDIO_UTILS_TAKC:-}" ]]; then
    bin=$AUDIO_UTILS_TAKC
    if [[ ! -e "$bin" && ! -x "$(command -v "$bin" 2>/dev/null || true)" ]]; then
      log_err "Error: AUDIO_UTILS_TAKC not found: $bin"
      return 1
    fi
    case "${bin,,}" in
      *.exe)
        if ! command -v wine >/dev/null 2>&1; then
          log_err "Error: AUDIO_UTILS_TAKC is a .exe but wine is not on PATH"
          log_err "  Install wine, or set AUDIO_UTILS_TAKC to a native Takc binary"
          return 1
        fi
        TAKC_CMD=(wine "$bin")
        ;;
      *)
        TAKC_CMD=("$bin")
        ;;
    esac
    : "${TAKC_CMD[@]}"
    return 0
  fi

  if command -v takc >/dev/null 2>&1; then
    TAKC_CMD=(takc)
    : "${TAKC_CMD[@]}"
    return 0
  fi
  if command -v Takc >/dev/null 2>&1; then
    TAKC_CMD=(Takc)
    : "${TAKC_CMD[@]}"
    return 0
  fi

  log_err "Error: Takc not found (set AUDIO_UTILS_TAKC, or install takc on PATH)"
  log_err "  Windows Takc.exe works under wine: AUDIO_UTILS_TAKC=/path/to/Takc.exe"
  return 1
}

# Encode WAV → DEST (.tak) with PRESET (p0–p5[em]).
takc_encode() {
  local wav="$1" dest="$2" preset="${3:-p2}"
  local err
  preset="${preset,,}"

  if ! takc_preset_ok "$preset"; then
    log_err "Error: invalid TAK preset '$preset' (expected p0-p5 with optional e/m)"
    return 1
  fi
  if ((${#TAKC_CMD[@]} == 0)); then
    takc_resolve || return 1
  fi

  err="$(dirname -- "$dest")/takc-encode.err"
  if ! "${TAKC_CMD[@]}" -e -p"$preset" -md5 -v -overwrite "$wav" "$dest" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED takc encode: $wav -> $dest (preset=$preset)"
    [[ -s "$err" ]] && { log_err "  takc stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
}

# Decode TAK → DEST_WAV via Takc.
takc_decode() {
  local tak="$1" dest_wav="$2"
  local err

  if ((${#TAKC_CMD[@]} == 0)); then
    takc_resolve || return 1
  fi

  err="$(dirname -- "$dest_wav")/takc-decode.err"
  if ! "${TAKC_CMD[@]}" -d -overwrite "$tak" "$dest_wav" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED takc decode: $tak -> $dest_wav"
    [[ -s "$err" ]] && { log_err "  takc stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
}

# Decode TAK → WAV: prefer ffmpeg, fall back to Takc.
# Args: SRC TMPDIR DEST_WAV
tak_decode_to_wav() {
  local src="$1" tmpdir="$2" wav="$3"
  local err
  err="${tmpdir}/tak-decode.err"
  if ffmpeg -v error -y -i "$src" -map 0:a:0 -c:a pcm_s24le "$wav" 2>"$err"; then
    return 0
  fi
  if takc_resolve 2>/dev/null; then
    if takc_decode "$src" "$wav"; then
      return 0
    fi
  fi
  set_last_err_file "$err"
  log_err "FAILED TAK decode (ffmpeg + takc): $src"
  [[ -s "$err" ]] && { log_err "  stderr:"; sed 's/^/  | /' "$err" >&2; }
  return 1
}
