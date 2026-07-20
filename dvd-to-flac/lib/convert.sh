#!/usr/bin/env bash
# VIDEO_TS (or containing) → per-stream FLACs from VOBs

_resolve_video_ts() {
  local path="$1"
  if [[ -d "$path" && "$(basename -- "$path")" == "VIDEO_TS" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  if [[ -d "$path/VIDEO_TS" ]]; then
    printf '%s\n' "$path/VIDEO_TS"
    return 0
  fi
  return 1
}

_extract_vob_streams() {
  local vob="$1" outdir="$2" tmpdir="$3"
  local base n i wav flac_out
  local -a enc_out
  local fail=0

  base=$(basename -- "$vob")
  base="${base%.*}"
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$vob" 2>/dev/null | grep -c . || true)
  n=${n:-0}
  ((n >= 1)) || return 0

  for ((i = 0; i < n; i++)); do
    flac_out="${outdir}/${base}.a${i}.flac"
    wav="${tmpdir}/${base}.a${i}.wav"

    if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]] && flac_ok "$flac_out"; then
      log_progress "skip (flac ok): $flac_out"
      log_success "$vob" "$flac_out" "$(audio_md5 "$flac_out")" "$(file_sha256 "$flac_out")" "skipped-existing-ok"
      continue
    fi

    if ! ffmpeg -v error -y -i "$vob" -map "0:a:${i}" -c:a pcm_s24le "$wav" 2>"${tmpdir}/ex.err"; then
      log_fail "$vob" "extract a:$i failed"
      fail=1
      continue
    fi
    if ! encode_flac_verified "$wav" "$tmpdir" "$vob#a$i" >"${tmpdir}/enc.out"; then
      log_fail "$vob" "encode a:$i failed"
      fail=1
      continue
    fi
    mapfile -t enc_out <"${tmpdir}/enc.out"
    mv -f -- "${enc_out[0]}" "$flac_out"
    log_info "verified: $flac_out"
    log_success "$vob" "$flac_out" "${enc_out[2]}" "$(file_sha256 "$flac_out")" "converted;stream=$i"
    rm -f -- "$wav" 2>/dev/null || true
  done
  return "$fail"
}

convert_one() {
  local path="$1"
  local video_ts outdir tmpdir vob fail=0

  if ! video_ts=$(_resolve_video_ts "$path"); then
    # If path is a VOB file, treat parent VIDEO_TS
    if [[ -f "$path" && "${path,,}" == *.vob ]]; then
      video_ts=$(dirname -- "$path")
    else
      log_fail "$path" "not a VIDEO_TS path"
      return 1
    fi
  fi

  outdir="$(dirname -- "$video_ts")/flac"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would extract DVD audio: $video_ts → $outdir/"
    while IFS= read -r -d '' vob; do
      log_info "  VOB: $(basename -- "$vob")"
    done < <(find "$video_ts" -maxdepth 1 -type f \( -iname 'VTS_*.VOB' -o -iname 'vts_*.vob' \) -print0 | sort -z)
    return 0
  fi

  mkdir -p -- "$outdir"
  tmpdir=$(make_workdir "$outdir")
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "dvd extract: $video_ts"
  while IFS= read -r -d '' vob; do
    if ! _extract_vob_streams "$vob" "$outdir" "$tmpdir"; then
      fail=1
    fi
  done < <(find "$video_ts" -maxdepth 1 -type f \( -iname 'VTS_*.VOB' -o -iname 'vts_*.vob' \) ! -iname '*_0.VOB' -print0 | sort -z)

  # Also try title-0 menu VOBs if nothing else? skip menus (*_0.VOB)

  cleanup
  ((fail == 0))
}
