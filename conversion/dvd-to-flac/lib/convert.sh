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
  local base n i flac_out
  local fail=0

  base=$(basename -- "$vob")
  base="${base%.*}"
  n=$(audio_stream_count "$vob")
  n=${n:-0}
  ((n >= 1)) || return 0

  for ((i = 0; i < n; i++)); do
    flac_out="${outdir}/${base}.a${i}.flac"
    if ! extract_audio_stream_to_flac "$vob" "$i" "$flac_out" "$tmpdir"; then
      fail=1
    fi
  done
  return "$fail"
}

convert_one() {
  local path="$1"
  local video_ts outdir tmpdir vob fail=0

  if ! video_ts=$(_resolve_video_ts "$path"); then
    if [[ -f "$path" && "${path,,}" == *.vob ]]; then
      video_ts=$(dirname -- "$path")
    else
      log_fail "$path" "not a VIDEO_TS path"
      return 1
    fi
  fi

  outdir="$(dirname -- "$video_ts")/flac"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would extract DVD audio: $video_ts -> $outdir/"
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

  cleanup
  [[ "$fail" -eq 0 ]]
}
