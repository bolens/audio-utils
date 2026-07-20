#!/usr/bin/env bash
# dsf-to-flac plugin — DSD (DSF/DFF) → PCM → FLAC.

AU_TOOL_NAME="${AU_TOOL_NAME:-dsf-to-flac}"
AU_SOURCE_EXT=dsf
AU_SOURCE_EXTS="dsf dff"
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=dsf2flac
AU_SUCCESS_COLUMNS='timestamp,src,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_SOURCE_LABEL=dsd

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { flac_ok "$2" && sibling_matches_source "$1" "$2"; }
convert_one() { to_flac_convert_one "$@"; }

plugin_accept_source() {
  local codec ext
  ext="${1##*.}"
  ext="${ext,,}"
  case "$ext" in
    dsf|dff) ;;
    *) return 1 ;;
  esac
  codec=$(audio_codec "$1" 2>/dev/null || true)
  # DSF usually probes as dsd_*; DFF may fail probe until sox — still accept by ext.
  case "$codec" in
    dsd_*|"") return 0 ;;
    *)
      # Some builds report other names; accept any audio in .dsf/.dff
      [[ -n "$codec" ]]
      ;;
  esac
}

# Decode DSD → integer PCM at AUDIO_UTILS_DSD_RATE (default 88200), 24-bit.
plugin_decode_prep() {
  local src="$1" tmpdir="$2"
  local rate="${AUDIO_UTILS_DSD_RATE:-88200}"
  local wav="${tmpdir}/dsd_pcm.wav"
  local err="${tmpdir}/dsd.err"
  local ext="${src##*.}"
  ext="${ext,,}"

  if ffmpeg -v error -y -i "$src" \
    -af "aresample=${rate}" -c:a pcm_s24le "$wav" 2>"$err"; then
    remux_verified "$wav" "$tmpdir" pcm_s24le
    return $?
  fi

  if [[ "$ext" == dff ]] && command -v sox >/dev/null 2>&1; then
    if sox "$src" -t wav -b 24 -r "$rate" "$wav" 2>"$err"; then
      remux_verified "$wav" "$tmpdir" pcm_s24le
      return $?
    fi
    set_last_err_file "$err"
    log_err "FAILED DFF decode via sox: $src"
    [[ -s "$err" ]] && { log_err "  sox stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi

  set_last_err_file "$err"
  log_err "FAILED DSD decode: $src"
  [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
  if [[ "$ext" == dff ]]; then
    log_err "  Tip: install sox for DFF (DSDIFF) when ffmpeg lacks a demuxer."
  fi
  return 1
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE" AU_SOURCE_LABEL
  export AUDIO_UTILS_DSD_RATE="${AUDIO_UTILS_DSD_RATE:-88200}"
}
