#!/usr/bin/env bash
# Extract each audio stream → basename.aN.flac

convert_one() {
  local src="$1"
  local base dest_dir tmpdir n i flac_out
  local fail=0

  base=$(basename -- "$src")
  base="${base%.*}"
  dest_dir=$(dirname -- "$src")
  n=$(audio_stream_count "$src")
  n=${n:-0}

  if ((n < 1)); then
    log_fail "$src" "no audio streams"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would extract: $src ($n audio stream(s))"
    for ((i = 0; i < n; i++)); do
      log_info "  → ${base}.a${i}.flac"
    done
    return 0
  fi

  tmpdir=$(make_workdir "$dest_dir")
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "extract: $src ($n streams)"
  AU_STREAM_TAG=1
  export AU_STREAM_TAG

  for ((i = 0; i < n; i++)); do
    flac_out="${dest_dir}/${base}.a${i}.flac"
    if ! extract_audio_stream_to_flac "$src" "$i" "$flac_out" "$tmpdir"; then
      fail=1
    fi
  done

  if [[ "${DELETE_SOURCE:-0}" -eq 1 && "$fail" -eq 0 ]]; then
    rm -f -- "$src"
    log_info "deleted: $src"
  fi

  cleanup
  [[ "$fail" -eq 0 ]]
}
