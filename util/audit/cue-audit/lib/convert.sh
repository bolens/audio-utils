#!/usr/bin/env bash
# Audit one CUE: image resolve, track list, UTF-8.

_cue_audit_multi() {
  local cue=$1 line key rest current_name='' current_image='' duration='' tracks=0
  local in_track=0 has_index=0 inum itime start
  # shellcheck disable=SC2094  # nested helper reads the same CUE; no writes
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}; line="${line#"${line%%[![:space:]]*}"}"
    [[ -n "$line" ]] || continue
    key=${line%%[[:space:]]*}; rest=${line#"$key"}
    rest="${rest#"${rest%%[![:space:]]*}"}"
    case "${key^^}" in
      FILE)
        ((in_track == 0 || has_index == 1)) || return 1
        current_name=$(cue_file_name_from_line "$rest")
        current_image=$(cue_resolve_named_image "$cue" "$current_name") || return 1
        duration=$(audio_duration_sec "$current_image") || return 1
        in_track=0; has_index=0
        ;;
      TRACK)
        [[ -n "$current_image" ]] || return 1
        ((in_track == 0 || has_index == 1)) || return 1
        in_track=1; has_index=0; ((tracks++)) || true
        ;;
      INDEX)
        ((in_track == 1)) || continue
        inum=${rest%%[[:space:]]*}; itime=${rest#"$inum"}
        itime="${itime#"${itime%%[![:space:]]*}"}"
        if [[ "$inum" == 01 || "$inum" == 1 ]]; then
          start=$(cue_msf_to_sec "$itime") || return 1
          awk -v s="$start" -v d="$duration" 'BEGIN { exit !(s >= 0 && s < d) }' || return 1
          has_index=1
        fi
        ;;
    esac
  done <"$cue"
  ((tracks > 0 && has_index == 1)) || return 1
  printf '%s\n' "$tracks"
}

convert_one() {
  local cue="$1" image name issues=() n duration last_start file_count=0
  local -a cue_images=()
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

  while IFS= read -r -d '' name; do
    ((file_count++)) || true
    if ! image=$(cue_resolve_named_image "$cue" "$name" 2>/dev/null); then
      issues+=("missing-image:$name"); continue
    fi
    cue_images+=("$image")
    [[ -s "$image" ]] || { issues+=("empty-image:$name"); continue; }
    audio_decode_ok "$image" || issues+=("unreadable-image:$name")
  done < <(cue_list_file_names0 "$cue")
  ((file_count > 0)) || issues+=("missing-image")
  image=${cue_images[0]:-}
  if ((file_count > 1)); then
    if n=$(_cue_audit_multi "$cue" 2>/dev/null); then :; else issues+=("parse-failed"); n=0; fi
  elif mapfile -t track_lines < <(cue_list_tracks "$cue" 2>/dev/null); then
    n=${#track_lines[@]}
    if ((n == 0)); then
      issues+=("no-tracks")
    fi
  else
    issues+=("parse-failed")
    n=0
  fi
  if ((file_count == 1)) && [[ -n "${image:-}" && ${#track_lines[@]} -gt 0 ]]; then
    duration=$(audio_duration_sec "$image" 2>/dev/null || true)
    last_start=${track_lines[${#track_lines[@]}-1]}
    IFS='|' read -r _ _ _ last_start _ <<<"$last_start"
    if [[ ! "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || \
      ! awk -v start="$last_start" -v duration="$duration" \
        'BEGIN { exit !(start >= 0 && start < duration) }'; then
      issues+=("index-outside-image")
    fi
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$cue" "cue audit issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $cue ($n tracks, images=$file_count)"
  log_success "$cue" "clean" "" "$(file_sha256 "$cue")" "tracks=$n;images=$file_count"
}
