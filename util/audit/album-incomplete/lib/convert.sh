#!/usr/bin/env bash
# Completeness audit for one album directory (first file claims the dir).

_ai_list_audio() {
  local dir=$1 ext
  local -a find_args=( -P "$dir" -maxdepth 1 -type f \( )
  local first=1
  # shellcheck disable=SC2086
  for ext in ${AU_SOURCE_EXTS:-${AU_AUDIO_EXTS_DEFAULT}}; do
    if [[ "$first" -eq 1 ]]; then
      find_args+=( -iname "*.${ext}" ); first=0
    else
      find_args+=( -o -iname "*.${ext}" )
    fi
  done
  find_args+=( \) )
  LC_ALL=C find "${find_args[@]}" | LC_ALL=C sort
}

# Print semicolon-joined issues (empty = complete).
_ai_audit_dir() {
  local dir=$1
  local -a files=() issues=() durs=()
  local f track disc tot td num dur
  local -A disc_nums=() disc_totals=() disc_seen=()
  local missing_track=0 total_discs="" max_disc=1 file_count=0
  local median short_n=0 long_n=0 ratio

  mapfile -t files < <(_ai_list_audio "$dir")
  file_count=${#files[@]}
  if ((file_count == 0)); then
    printf '\n'
    return 0
  fi

  for f in "${files[@]}"; do
    disc=$(audio_meta_get "$f" DISCNUMBER)
    [[ -n "$disc" ]] || disc=$(audio_meta_get "$f" disc)
    disc=${disc%%/*}
    [[ "$disc" =~ ^[0-9]+$ ]] || disc=1
    disc=$((10#$disc))
    disc_seen[$disc]=1
    ((disc > max_disc)) && max_disc=$disc

    td=$(audio_meta_get "$f" TOTALDISCS)
    [[ -n "$td" ]] || td=$(audio_meta_get "$f" DISCTOTAL)
    td=${td%%/*}
    if [[ "$td" =~ ^[0-9]+$ ]]; then
      td=$((10#$td))
      if [[ -z "$total_discs" || "$td" -gt "$total_discs" ]]; then
        total_discs=$td
      fi
    fi

    track=$(audio_meta_get "$f" TRACKNUMBER)
    [[ -n "$track" ]] || track=$(audio_meta_get "$f" track)
    tot=""
    if [[ "$track" == */* ]]; then
      tot=${track#*/}
      track=${track%%/*}
    fi
    [[ -n "$tot" ]] || tot=$(audio_meta_get "$f" TOTALTRACKS)
    [[ -n "$tot" ]] || tot=$(audio_meta_get "$f" TRACKTOTAL)

    if [[ "$track" =~ ^[0-9]+$ ]]; then
      num=$((10#$track))
      disc_nums[$disc]="${disc_nums[$disc]:-} $num"
    else
      ((missing_track++)) || true
    fi

    if [[ "$tot" =~ ^[0-9]+$ ]]; then
      tot=$((10#$tot))
      if [[ -z "${disc_totals[$disc]:-}" || "$tot" -gt "${disc_totals[$disc]}" ]]; then
        disc_totals[$disc]=$tot
      fi
    fi

    if [[ "${INCOMPLETE_NO_DURATION:-0}" -eq 0 ]]; then
      dur=$(audio_duration_sec "$f" 2>/dev/null || true)
      if [[ "$dur" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        durs+=("$dur")
      fi
    fi
  done

  ((missing_track == 0)) || issues+=("missing-track:${missing_track}")

  # Per-disc: contiguity 1..N and count vs TOTALTRACKS.
  local d count max min
  local -a nums=()
  for d in "${!disc_nums[@]}"; do
    mapfile -t nums < <(tr ' ' '\n' <<<"${disc_nums[$d]}" | sed '/^$/d' | sort -n -u)
    count=${#nums[@]}
    ((count > 0)) || continue
    min=${nums[0]}
    max=${nums[count - 1]}
    if ((min != 1 || max != count)); then
      issues+=("track-gaps:disc${d}")
    fi
    if [[ -n "${disc_totals[$d]:-}" ]]; then
      if ((count < disc_totals[$d])); then
        issues+=("incomplete-tracks:disc${d}:${count}/${disc_totals[$d]}")
      elif ((count > disc_totals[$d])); then
        issues+=("extra-tracks:disc${d}:${count}/${disc_totals[$d]}")
      fi
    fi
  done

  # TOTALDISCS says N but fewer distinct DISCNUMBER values present.
  if [[ -n "$total_discs" && "$total_discs" -gt 1 ]]; then
    local present=${#disc_seen[@]}
    if ((present < total_discs)); then
      issues+=("incomplete-discs:${present}/${total_discs}")
    fi
    # Also: TOTALDISCS=N but max DISCNUMBER < N (same signal, keep one label).
  elif ((max_disc > 1 && ${#disc_seen[@]} < max_disc)); then
    issues+=("incomplete-discs:${#disc_seen[@]}/${max_disc}")
  fi

  # Duration outliers vs median (truncated / wrong-file inserts).
  if [[ "${INCOMPLETE_NO_DURATION:-0}" -eq 0 && ${#durs[@]} -ge 3 ]]; then
    ratio=${INCOMPLETE_DUR_RATIO:-0.35}
    mapfile -t durs < <(printf '%s\n' "${durs[@]}" | sort -n)
    local mid=$(( ${#durs[@]} / 2 ))
    median=${durs[mid]}
    if awk -v m="$median" 'BEGIN { exit !(m+0 > 0) }'; then
      local x
      for x in "${durs[@]}"; do
        if awk -v x="$x" -v m="$median" -v r="$ratio" \
          'BEGIN { exit !(x+0 < m*r) }'; then
          ((short_n++)) || true
        elif awk -v x="$x" -v m="$median" -v r="$ratio" \
          'BEGIN { exit !(x+0 > m/r) }'; then
          ((long_n++)) || true
        fi
      done
      ((short_n == 0)) || issues+=("duration-short:${short_n}")
      ((long_n == 0)) || issues+=("duration-long:${long_n}")
    fi
  fi

  local IFS=';'
  printf '%s\n' "${issues[*]}"
}

convert_one() {
  local src="$1" dir key lock result_f issues n

  dir=$(cd -- "$(dirname -- "$src")" && pwd) || {
    log_fail "$src" "cannot resolve directory"
    return 1
  }

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would album-incomplete: $dir"
    return 0
  fi

  key=$(au_sha256_str "$dir")
  lock="${AU_INCOMP_STATE:?}/${key}.lock"
  result_f="${AU_INCOMP_STATE}/${key}.result"

  if ! mkdir -- "${AU_INCOMP_STATE}/${key}.claim" 2>/dev/null; then
    log_progress "covered by dir audit: $src"
    log_success "$src" "skip" "" "" "dir-covered"
    return 0
  fi

  (
    flock 9
    _ai_audit_dir "$dir" >"$result_f"
  ) 9>"$lock"

  issues=$(head -n1 -- "$result_f" 2>/dev/null || true)
  n=$(_ai_list_audio "$dir" | wc -l | tr -d ' ')

  if [[ -n "$issues" ]]; then
    log_fail "$dir" "album incomplete" "$issues"
    return 1
  fi

  log_progress "ok: $dir ($n tracks)"
  log_success "$dir" "complete" "" "" "tracks=$n"
}
