#!/usr/bin/env bash
# Trim leading/trailing silence from one FLAC/PCM file (report or --apply).

# Print "start|end|dur|notes" for the keep window. Exit 1 if nothing to trim
# or the file is unusable; exit 2 if trim would leave too little audio.
_st_bounds() {
  local src=$1
  local report dur sil_d sil_db pad
  local -a starts=() ends=()
  local i n lead=0 trail lead_raw=0 trail_raw="" notes="" s e=""

  sil_d=${ST_SILENCE_SEC:-1.0}
  sil_db=${ST_SILENCE_DB:--50}
  pad=${ST_PAD_SEC:-0.05}

  dur=$(audio_duration_sec "$src") || return 1
  if ! awk -v d="$dur" 'BEGIN { exit !(d+0 > 0) }'; then
    return 1
  fi
  trail=$dur
  trail_raw=$dur

  report=$(ffmpeg -hide_banner -nostats -i "$src" \
    -af "silencedetect=noise=${sil_db}dB:d=${sil_d}" \
    -f null - 2>&1) || true

  while IFS= read -r line; do
    case "$line" in
      *silence_start:*)
        starts+=("$(awk '{print $NF+0}' <<<"$line")")
        ;;
      *silence_end:*)
        ends+=("$(awk '{
          for (i=1;i<=NF;i++) if ($i ~ /^silence_end:/) { print $(i+1)+0; exit }
          if ($1 ~ /silence_end:/) { print $2+0; exit }
        }' <<<"$line")")
        ;;
    esac
  done < <(printf '%s\n' "$report" | grep -E 'silence_start:|silence_end:')

  n=${#starts[@]}
  if [[ "${ST_LEAD:-1}" -eq 1 && "$n" -gt 0 ]]; then
    if awk -v s="${starts[0]}" 'BEGIN { exit !(s+0 <= 0.05) }'; then
      if [[ -n "${ends[0]:-}" ]]; then
        lead_raw=${ends[0]}
        lead=$(awk -v e="$lead_raw" -v p="$pad" 'BEGIN {
          v = e - p; if (v < 0) v = 0; printf "%.3f", v
        }')
        notes+="lead:${lead_raw}"
      elif awk -v d="$dur" 'BEGIN { exit !(d+0 > 0) }'; then
        # Leading silence with no end ⇒ whole file is silence.
        lead_raw=$dur
        lead=$dur
        notes+="lead:${lead_raw}"
      fi
    fi
  fi

  if [[ "${ST_TRAIL:-1}" -eq 1 && "$n" -gt 0 ]]; then
    for ((i = n - 1; i >= 0; i--)); do
      s=${starts[i]}
      e=${ends[i]:-}
      # Trailing silence: runs to EOF (no end, or end ≈ duration).
      if [[ -z "$e" ]] || awk -v e="$e" -v d="$dur" 'BEGIN { exit !(e+0 >= d - 0.05) }'; then
        trail_raw=$s
        trail=$(awk -v s="$s" -v p="$pad" -v d="$dur" 'BEGIN {
          v = s + p; if (v > d) v = d; printf "%.3f", v
        }')
        notes+="${notes:+,}trail:${trail_raw}"
        break
      fi
    done
  fi

  # Nothing meaningful to cut.
  if awk -v a="$lead" -v b="$trail" -v d="$dur" 'BEGIN {
    exit !((a+0 <= 0.01) && (b+0 >= d - 0.01))
  }'; then
    return 1
  fi

  if ! awk -v a="$lead" -v b="$trail" -v m="${ST_MIN_KEEP:-1.0}" 'BEGIN {
    exit !((b - a) + 0 >= m + 0)
  }'; then
    printf '%s|%s|%s|%s\n' "$lead" "$trail" "$dur" "too-short;${notes}"
    return 2
  fi

  notes=$(flac_tag_trim "$notes")
  printf '%s|%s|%s|%s\n' "$lead" "$trail" "$dur" "${notes:-trim}"
  return 0
}

_st_write_trim() {
  local src=$1 start=$2 end=$3 dest=$4
  local len err ext codec
  len=$(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.3f", b - a }')
  err="${dest}.err"
  ext=${src##*.}
  ext=${ext,,}

  case "$ext" in
    flac)
      if ! ffmpeg -hide_banner -nostats -y -ss "$start" -t "$len" -i "$src" \
        -map 0:a:0 -c:a flac -compression_level 5 \
        "$dest" 2>"$err"; then
        set_last_err_file "$err"
        return 1
      fi
      ;;
    *)
      codec=$(audio_codec "$src") || codec=""
      if [[ -z "$codec" ]]; then
        printf 'cannot detect codec\n' >"$err"
        set_last_err_file "$err"
        return 1
      fi
      if ! ffmpeg -hide_banner -nostats -y -ss "$start" -t "$len" -i "$src" \
        -map 0:a:0 -c:a "$codec" -map_metadata 0 \
        "$dest" 2>"$err"; then
        set_last_err_file "$err"
        return 1
      fi
      ;;
  esac
  rm -f -- "$err"
  return 0
}

_st_parse_bounds() {
  # $1 = "start|end|dur|notes" → sets start end dur notes in caller via nameref-less globals
  local _line=$1
  start=${_line%%|*}
  _line=${_line#*|}
  end=${_line%%|*}
  _line=${_line#*|}
  dur=${_line%%|*}
  notes=${_line#*|}
}

convert_one() {
  local src="$1" dir tmp out tagged
  local start end dur notes rc=0 line ext

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if line=$(_st_bounds "$src"); then
      _st_parse_bounds "$line"
      log_progress "would trim: $src (${start}s -> ${end}s of ${dur}s; ${notes})"
    else
      rc=$?
      if [[ "$rc" -eq 2 ]]; then
        log_progress "would skip (too short after trim): $src"
      else
        log_progress "would skip (no edge silence): $src"
      fi
    fi
    return 0
  fi

  if ! line=$(_st_bounds "$src"); then
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      _st_parse_bounds "${line:-0|0|0|min-keep=${ST_MIN_KEEP}}"
      log_fail "$src" "trim would leave too little audio" "${notes}"
      return 1
    fi
    log_progress "ok (no edge silence): $src"
    log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "clean"
    return 0
  fi
  _st_parse_bounds "$line"

  if [[ "${ST_APPLY:-0}" -eq 0 ]]; then
    log_fail "$src" "trim candidate" "${start}->${end}/${dur};${notes}"
    return 1
  fi

  dir=$(dirname -- "$src")
  tmp=$(make_workdir "$dir")
  ext=${src##*.}
  out="${tmp}/trimmed.${ext}"
  tagged="${tmp}/tagged.flac"

  cleanup() {
    unregister_tmpdir "$tmp"
    rm -rf -- "$tmp" 2>/dev/null || true
  }

  if ! _st_write_trim "$src" "$start" "$end" "$out"; then
    log_fail "$src" "trim encode failed" "$notes"
    cleanup
    return 1
  fi

  case "${ext,,}" in
    flac)
      if ! flac_ok "$out"; then
        log_fail "$src" "trimmed flac -t failed"
        cleanup
        return 1
      fi
      if ! tag_flac_from_source "$src" "$out" "$tagged"; then
        log_fail "$src" "restore tags/cover failed"
        cleanup
        return 1
      fi
      if ! mv -f -- "$tagged" "$src"; then
        log_fail "$src" "replace failed"
        cleanup
        return 1
      fi
      ;;
    *)
      if ! mv -f -- "$out" "$src"; then
        log_fail "$src" "replace failed"
        cleanup
        return 1
      fi
      ;;
  esac
  cleanup

  log_progress "trimmed: $src (${start}s -> ${end}s; ${notes})"
  log_success "$src" "trimmed" "$(audio_md5 "$src")" "$(file_sha256 "$src")" \
    "${start}->${end};${notes}"
}
