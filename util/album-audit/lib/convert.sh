#!/usr/bin/env bash
# Audit one directory as an album unit; the first file claims the work.

_aa_list_audio() {
  local dir=$1
  LC_ALL=C find -P "$dir" -maxdepth 1 -type f \
    \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.opus' \
    -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.oga' \
    -o -iname '*.wma' -o -iname '*.mpc' -o -iname '*.aac' \) \
    | LC_ALL=C sort
}

# Audit DIR; print semicolon-joined issues to stdout (empty line = clean).
_aa_audit_dir() {
  local dir=$1
  local -a files=() issues=()
  local f album aartist artist date track disc num tot rate depth
  local -A albums=() aartists=() artists=() dates=() rates=() depths=()
  local -A seen=() disc_nums=() disc_totals=()
  local missing_album=0 missing_track=0 dup_track=0 total_bad=0

  mapfile -t files < <(_aa_list_audio "$dir")
  if ((${#files[@]} == 0)); then
    printf '\n'
    return 0
  fi

  for f in "${files[@]}"; do
    album=$(audio_meta_get "$f" ALBUM)
    if [[ -n "$album" ]]; then
      albums["$album"]=1
    else
      ((missing_album++)) || true
    fi

    aartist=$(audio_meta_get "$f" ALBUMARTIST)
    [[ -n "$aartist" ]] || aartist=$(audio_meta_get "$f" album_artist)
    [[ -z "$aartist" ]] || aartists["$aartist"]=1

    artist=$(audio_meta_get "$f" ARTIST)
    [[ -z "$artist" ]] || artists["$artist"]=1

    date=$(audio_meta_get "$f" DATE)
    [[ -n "$date" ]] || date=$(audio_meta_get "$f" year)
    [[ -z "$date" ]] || dates["$date"]=1

    disc=$(audio_meta_get "$f" DISCNUMBER)
    [[ -n "$disc" ]] || disc=$(audio_meta_get "$f" disc)
    disc=${disc%%/*}
    [[ "$disc" =~ ^[0-9]+$ ]] || disc=1
    disc=$((10#$disc))

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
      if [[ -n "${seen[$disc/$num]:-}" ]]; then
        ((dup_track++)) || true
      fi
      seen["$disc/$num"]=1
      disc_nums[$disc]="${disc_nums[$disc]:-} $num"
    else
      ((missing_track++)) || true
    fi

    if [[ "$tot" =~ ^[0-9]+$ ]]; then
      tot=$((10#$tot))
      if [[ -n "${disc_totals[$disc]:-}" && "${disc_totals[$disc]}" -ne "$tot" ]]; then
        ((total_bad++)) || true
      fi
      disc_totals[$disc]=$tot
    fi

    if [[ "${f,,}" == *.flac ]]; then
      rate=$(audio_sample_rate "$f" 2>/dev/null) || rate=""
      depth=$(audio_bits_per_sample "$f" 2>/dev/null) || depth=""
      [[ -z "$rate" ]] || rates["$rate"]=1
      [[ -z "$depth" ]] || depths["$depth"]=1
    fi
  done

  ((missing_album == 0)) || issues+=("missing-album:${missing_album}")
  ((${#albums[@]} <= 1)) || issues+=("mixed-album:${#albums[@]}")
  ((missing_track == 0)) || issues+=("missing-track:${missing_track}")
  ((dup_track == 0)) || issues+=("dup-track:${dup_track}")
  ((${#aartists[@]} <= 1)) || issues+=("mixed-albumartist:${#aartists[@]}")
  if ((${#aartists[@]} == 0 && ${#artists[@]} > 1)); then
    issues+=("va-no-albumartist:${#artists[@]}")
  fi
  ((${#dates[@]} <= 1)) || issues+=("mixed-date:${#dates[@]}")
  ((${#rates[@]} <= 1)) || issues+=("mixed-rate")
  ((${#depths[@]} <= 1)) || issues+=("mixed-depth")
  ((total_bad == 0)) || issues+=("totaltracks-inconsistent")

  # Per-disc contiguity 1..N and count vs declared total.
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
    if [[ -n "${disc_totals[$d]:-}" && "${disc_totals[$d]}" -ne "$count" ]]; then
      issues+=("totaltracks-mismatch:disc${d}:${count}/${disc_totals[$d]}")
    fi
  done

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
    log_progress "would album-audit: $dir"; return 0
  fi

  key=$(au_sha256_str "$dir")
  lock="${AU_ALBAUDIT_STATE:?}/${key}.lock"
  result_f="${AU_ALBAUDIT_STATE}/${key}.result"

  # First file in the directory claims the audit; the rest are covered.
  if ! mkdir -- "${AU_ALBAUDIT_STATE}/${key}.claim" 2>/dev/null; then
    log_progress "covered by dir audit: $src"
    log_success "$src" "skip" "" "" "dir-covered"
    return 0
  fi

  (
    flock 9
    _aa_audit_dir "$dir" >"$result_f"
  ) 9>"$lock"

  issues=$(head -n1 -- "$result_f" 2>/dev/null || true)
  n=$(_aa_list_audio "$dir" | wc -l | tr -d ' ')

  if [[ -n "$issues" ]]; then
    log_fail "$dir" "album audit issues" "$issues"
    return 1
  fi

  log_progress "ok: $dir ($n tracks)"
  log_success "$dir" "clean" "" "" "tracks=$n"
}
