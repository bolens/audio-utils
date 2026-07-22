#!/usr/bin/env bash
# CDDA rip helpers via cdparanoia.

cdda_require() {
  require_cmds cdparanoia
}

# Rip TRACKNUM (1-based) from DEVICE to OUT_WAV (WAV).
cdda_rip_track() {
  local device="$1" tracknum="$2" out_wav="$3"
  local err

  [[ -n "$device" && -n "$tracknum" && -n "$out_wav" ]] || {
    log_err "Error: cdda_rip_track requires DEVICE TRACKNUM OUT_WAV"
    return 1
  }
  cdda_require || return 1

  err="$(dirname -- "$out_wav")/cdda-rip.err"
  # -d device, -w force WAV, track-track range of one track.
  if ! cdparanoia -d "$device" -w "${tracknum}-${tracknum}" "$out_wav" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED cdparanoia rip: device=$device track=$tracknum -> $out_wav"
    [[ -s "$err" ]] && { log_err "  cdparanoia stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
}

# Print audio track count for DEVICE (cdparanoia -Q).
cdda_track_count() {
  local device="$1"
  local out count

  [[ -n "$device" ]] || {
    log_err "Error: cdda_track_count requires DEVICE"
    return 1
  }
  cdda_require || return 1

  # -Q queries TOC; track lines look like "  1. ..." before TOTAL.
  out=$(cdparanoia -d "$device" -Q 2>&1) || true
  count=$(printf '%s\n' "$out" | awk '
    /^[[:space:]]*[0-9]+\./ { n++ }
    END { print n+0 }
  ')
  if [[ -z "$count" || "$count" -eq 0 ]]; then
    log_err "Error: could not read CDDA TOC from $device"
    [[ -n "$out" ]] && log_err "  cdparanoia: $(printf '%s' "$out" | tr '\n' ' ' | head -c 200)"
    return 1
  fi
  printf '%s\n' "$count"
}
