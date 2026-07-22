#!/usr/bin/env bash
# Split one long audio file on silence into numbered FLAC tracks.

# Collect silence regions; print "start end" pairs of keep segments to stdout.
# Uses ffmpeg silencedetect. Segments shorter than SS_MIN_TRACK are dropped.
_ss_segments() {
  local src=$1
  local report dur min_t sil_d sil_db
  local -a starts=() ends=()
  local i n seg_start seg_end len

  min_t=${SS_MIN_TRACK:-10}
  sil_d=${SS_SILENCE_SEC:-2.0}
  sil_db=${SS_SILENCE_DB:--50}

  dur=$(audio_duration_sec "$src") || return 1
  if ! awk -v d="$dur" 'BEGIN { exit !(d+0 > 0) }'; then
    return 1
  fi

  report=$(ffmpeg -hide_banner -nostats -i "$src" \
    -af "silencedetect=noise=${sil_db}dB:d=${sil_d}" \
    -f null - 2>&1) || true

  # Parse silence_start / silence_end chronologically.
  while IFS= read -r line; do
    case "$line" in
      *silence_start:*)
        starts+=("$(awk '{print $NF+0}' <<<"$line")")
        ;;
      *silence_end:*)
        # "silence_end: X | silence_duration: Y"
        ends+=("$(awk '{
          for (i=1;i<=NF;i++) if ($i ~ /^silence_end:/) { print $(i+1)+0; exit }
          if ($1 ~ /silence_end:/) { print $2+0; exit }
        }' <<<"$line")")
        ;;
    esac
  done < <(printf '%s\n' "$report" | grep -E 'silence_start:|silence_end:')

  # Build keep segments: [0, first_silence_start), (silence_end, next_start), … (last_end, dur)
  local -a cuts_start=(0) cuts_end=()
  n=${#starts[@]}
  # Pair starts[i] with ends[i] when available
  for ((i = 0; i < n; i++)); do
    cuts_end+=("${starts[i]}")
    if [[ -n "${ends[i]:-}" ]]; then
      cuts_start+=("${ends[i]}")
    fi
  done
  cuts_end+=("$dur")

  local out_n=0
  for ((i = 0; i < ${#cuts_start[@]} && i < ${#cuts_end[@]}; i++)); do
    seg_start=${cuts_start[i]}
    seg_end=${cuts_end[i]}
    len=$(awk -v a="$seg_start" -v b="$seg_end" 'BEGIN { printf "%.3f", b - a }')
    if awk -v l="$len" -v m="$min_t" 'BEGIN { exit !(l+0 >= m+0) }'; then
      printf '%s %s\n' "$seg_start" "$seg_end"
      ((out_n++)) || true
    fi
  done

  ((out_n > 0))
}

_ss_extract_flac() {
  local src=$1 start=$2 end=$3 dest=$4
  local len err
  len=$(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.3f", b - a }')
  err="${dest}.err"
  if ! ffmpeg -hide_banner -nostats -y -ss "$start" -t "$len" -i "$src" \
    -map 0:a:0 -c:a flac -compression_level 5 \
    -map_metadata 0 "$dest" 2>"$err"; then
    set_last_err_file "$err"
    return 1
  fi
  rm -f -- "$err"
  flac_ok "$dest"
}

convert_one() {
  local src="$1" dest_dir base tmpdir
  local -a segs=()
  local line start end idx name out n=0 fail=0

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if mapfile -t segs < <(_ss_segments "$src"); then
      log_progress "would silence-split: $src (${#segs[@]} tracks)"
      for line in "${segs[@]}"; do
        read -r start end <<<"$line"
        log_info "  ${start}s -> ${end}s"
      done
    else
      log_progress "would silence-split: $src (no segments / too short)"
    fi
    return 0
  fi

  if ! mapfile -t segs < <(_ss_segments "$src"); then
    log_fail "$src" "no split segments" "silence=${SS_SILENCE_SEC}s min=${SS_MIN_TRACK}s"
    return 1
  fi

  if ((${#segs[@]} < 2)); then
    log_fail "$src" "fewer than 2 tracks after silence split" "segments=${#segs[@]}"
    return 1
  fi

  if [[ -n "${SS_OUTDIR}" ]]; then
    dest_dir=${SS_OUTDIR}
    mkdir -p -- "$dest_dir" || {
      log_fail "$src" "cannot create outdir" "$dest_dir"
      return 1
    }
  else
    dest_dir=$(dirname -- "$src")
  fi

  base=$(basename -- "${src%.*}")
  tmpdir=$(make_workdir "$dest_dir")
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "split: $src -> ${#segs[@]} tracks"

  idx=1
  for line in "${segs[@]}"; do
    read -r start end <<<"$line"
    name=$(printf '%s - %02d.flac' "$base" "$idx")
    out="${dest_dir}/${name}"

    if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      if flac_ok "$out"; then
        log_progress "skip (exists): $out"
        log_success "$src" "$out" "$(audio_md5 "$out")" "$(file_sha256 "$out")" "skipped-existing"
        ((idx++)) || true
        ((n++)) || true
        continue
      fi
    fi

    local tmp_out
    tmp_out="${tmpdir}/$(printf '%02d.flac' "$idx")"
    if ! _ss_extract_flac "$src" "$start" "$end" "$tmp_out"; then
      log_fail "$src" "extract failed" "track=$idx start=$start end=$end"
      fail=1
      break
    fi
    if ! mv -f -- "$tmp_out" "$out"; then
      log_fail "$src" "move failed" "$out"
      fail=1
      break
    fi
    log_progress "wrote: $out"
    log_success "$src" "$out" "$(audio_md5 "$out")" "$(file_sha256 "$out")" "track=$idx"
    ((idx++)) || true
    ((n++)) || true
  done

  cleanup

  if [[ "$fail" -eq 1 ]]; then
    return 1
  fi

  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    if rm -f -- "$src"; then
      log_info "deleted source: $src"
    else
      log_fail "$src" "split ok but source delete failed"
      return 1
    fi
  fi

  log_progress "done: $src ($n tracks)"
  return 0
}
