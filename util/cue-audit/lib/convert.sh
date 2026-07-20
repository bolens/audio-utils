#!/usr/bin/env bash
# Audit one CUE: image resolve, track list, UTF-8.

convert_one() {
  local cue="$1" image issues=() n
  local -a track_lines=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would audit-cue: $cue"; return 0
  fi

  # UTF-8 check when iconv is available
  if command -v iconv >/dev/null 2>&1; then
    if ! iconv -f UTF-8 -t UTF-8 -- "$cue" >/dev/null 2>&1; then
      issues+=("non-utf8")
    fi
  fi

  if ! image=$(cue_resolve_image "$cue" 2>/dev/null); then
    issues+=("missing-image")
  elif [[ ! -s "$image" ]]; then
    issues+=("empty-image")
  fi

  if mapfile -t track_lines < <(cue_list_tracks "$cue" 2>/dev/null); then
    n=${#track_lines[@]}
    if ((n == 0)); then
      issues+=("no-tracks")
    fi
  else
    issues+=("parse-failed")
    n=0
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$cue" "cue audit issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $cue ($n tracks, image=$(basename -- "$image"))"
  log_success "$cue" "clean" "" "$(file_sha256 "$cue")" "tracks=$n"
}
