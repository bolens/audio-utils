#!/usr/bin/env bash
# Collect per-FLAC inventory row; summary printed in plugin_finalize.

convert_one() {
  local flac="$1"
  local rate bps ch bytes dur rg=0 art=0 ok=0 sha
  local rows="${AU_INV_STATE:?}/rows.tsv"
  local lock="${AU_INV_STATE}/rows.lock"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would inventory: $flac"
    return 0
  fi

  if flac_ok "$flac"; then
    ok=1
  else
    log_fail "$flac" "flac -t failed"
    # Still record a row for broken files
    (
      flock 9
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$flac" "?" "?" "?" "$(file_bytes "$flac")" "0" "0" "0" "0" >>"$rows"
    ) 9>"$lock"
    return 1
  fi

  rate=$(audio_sample_rate "$flac") || rate="?"
  bps=$(audio_bits_per_sample "$flac") || bps="?"
  ch=$(audio_channels "$flac") || ch="?"
  bytes=$(file_bytes "$flac")
  dur=$(audio_duration_sec "$flac") || dur=0

  if [[ -n "$(flac_tag_get "$flac" REPLAYGAIN_TRACK_GAIN)" ]]; then
    rg=1
  fi
  if flac_has_picture "$flac"; then
    art=1
  fi

  (
    flock 9
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$flac" "$rate" "$bps" "$ch" "$bytes" "$dur" "$rg" "$art" "$ok" >>"$rows"
  ) 9>"$lock"

  sha=$(file_sha256 "$flac")
  log_progress "inventoried: $flac"
  log_success "$flac" "ok" "" "$sha" \
    "rate=${rate};bps=${bps};ch=${ch};rg=${rg};art=${art}"
}
