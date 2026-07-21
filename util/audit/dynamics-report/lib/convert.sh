#!/usr/bin/env bash
# Measure one file with ffmpeg ebur128; summary printed in plugin_finalize.

convert_one() {
  local f="$1" out lufs lra peak
  local rows="${AU_DYN_STATE:?}/rows.tsv"
  local lock="${AU_DYN_STATE}/rows.lock"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would measure: $f"
    return 0
  fi

  out=$(ffmpeg -hide_banner -nostats -i "$f" -map a:0 \
    -af ebur128=peak=true -f null - 2>&1) || {
    log_fail "$f" "ffmpeg ebur128 failed"
    return 1
  }

  # Parse the summary block: I / LRA / true Peak.
  read -r lufs lra peak < <(printf '%s\n' "$out" | awk '
    $1 == "I:" { i = $2 }
    $1 == "LRA:" && $3 == "LU" { l = $2 }
    $1 == "Peak:" { p = $2 }
    END { printf "%s %s %s\n", (i == "" ? "?" : i), (l == "" ? "?" : l), (p == "" ? "?" : p) }
  ')

  if [[ "$lufs" == "?" && "$lra" == "?" ]]; then
    log_fail "$f" "could not parse ebur128 summary"
    return 1
  fi

  (
    flock 9
    printf '%s\t%s\t%s\t%s\n' "$f" "$lufs" "$lra" "$peak" >>"$rows"
  ) 9>"$lock"

  log_progress "measured: $f (I=${lufs} LUFS, LRA=${lra} LU, peak=${peak} dBFS)"
  log_success "$f" "ok" "" "" "lufs=${lufs};lra=${lra};peak=${peak}"
}
