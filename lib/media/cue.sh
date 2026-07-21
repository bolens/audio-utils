#!/usr/bin/env bash
# CUE sheet parse, image resolve, and sample-accurate segment extract.

# MM:SS:FF (CD frames, 75/sec) → seconds (float).
cue_msf_to_sec() {
  local msf="$1"
  local mm ss ff
  IFS=: read -r mm ss ff <<<"$msf" || return 1
  [[ -n "$mm" && -n "$ss" && -n "$ff" ]] || return 1
  awk -v mm="$mm" -v ss="$ss" -v ff="$ff" 'BEGIN {
    printf "%.8f\n", (mm * 60) + ss + (ff / 75.0)
  }'
}

# Strip CUE quotes and surrounding whitespace.
cue_unquote() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  if [[ "${s:0:1}" == '"' && "${s: -1}" == '"' && ${#s} -ge 2 ]]; then
    s="${s:1:${#s}-2}"
  fi
  printf '%s' "$s"
}

# Filename from a FILE line: FILE "name.ext" TYPE  or  FILE name.ext TYPE
cue_file_name_from_line() {
  local rest="$1" name
  rest="${rest#"${rest%%[![:space:]]*}"}"
  if [[ "${rest:0:1}" == '"' ]]; then
    name="${rest#\"}"
    name="${name%%\"*}"
  else
    name="${rest%%[[:space:]]*}"
  fi
  printf '%s' "$name"
}

# Sanitize a track title for use as a filename component.
cue_sanitize_filename() {
  local s="$1" out c i
  out=""
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      /|\\|\<|\>|:|\"|\||\?|\*|$'\n'|$'\r'|$'\t') out+="_" ;;
      *) out+="$c" ;;
    esac
  done
  s=$out
  s="${s#"${s%%[![:space:].]*}"}"
  s="${s%"${s##*[![:space:].]}"}"
  while [[ "$s" == *"  "* ]]; do
    s=${s//  / }
  done
  [[ -n "$s" ]] || s="track"
  printf '%s\n' "$s"
}

# Absolute path to the audio image referenced by FILE in the CUE.
cue_resolve_image() {
  local cue_path="$1"
  local cue_dir line rest found="" candidate stem ext base lower
  local -a try_exts

  [[ -f "$cue_path" ]] || {
    log_err "Error: CUE not found: $cue_path"
    return 1
  }
  cue_dir=$(cd "$(dirname -- "$cue_path")" && pwd) || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    line="${line#"${line%%[![:space:]]*}"}"
    case "${line^^}" in
      FILE[[:space:]]*)
        rest=${line#*[Ff][Ii][Ll][Ee]}
        found=$(cue_file_name_from_line "$rest")
        break
        ;;
    esac
  done <"$cue_path"

  if [[ -z "$found" ]]; then
    log_err "Error: no FILE directive in CUE: $cue_path"
    return 1
  fi

  if [[ "$found" == /* ]]; then
    candidate=$found
  else
    candidate="${cue_dir}/${found}"
  fi

  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$(cd "$(dirname -- "$candidate")" && pwd)/$(basename -- "$candidate")"
    return 0
  fi

  try_exts=(wav flac ape mp3 aiff aif wv tak bin)
  stem="${found%.*}"
  for ext in "${try_exts[@]}"; do
    for candidate in \
      "${cue_dir}/${stem}.${ext}" \
      "${cue_dir}/${stem}.${ext^^}" \
      "${cue_dir}/${found}" \
      "${cue_dir}/${found,,}"; do
      [[ -f "$candidate" ]] || continue
      printf '%s\n' "$(cd "$(dirname -- "$candidate")" && pwd)/$(basename -- "$candidate")"
      return 0
    done
  done

  base=$(basename -- "$found")
  lower=${base,,}
  while IFS= read -r -d '' candidate; do
    if [[ "$(basename -- "$candidate")" == "$base" ]] ||
      [[ "$(basename -- "${candidate,,}")" == "$lower" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$cue_dir" -maxdepth 1 -type f -print0 2>/dev/null)

  log_err "Error: CUE image not found: $found (beside $cue_path)"
  return 1
}

# Print tracks: INDEX|TITLE|PERFORMER|START_SEC|END_SEC
# END_SEC empty for the last track (caller uses full duration).
# Pipe delimiter avoids bash IFS collapsing empty tab fields.
cue_list_tracks() {
  local cue_path="$1"
  local line key rest key_u track_num="" album_title="" album_perf=""
  local title="" performer="" index01="" in_track=0
  local inum itime start_sec i next_start end_sec
  local -a idx_nums=() titles=() perfs=() starts=()

  [[ -f "$cue_path" ]] || {
    log_err "Error: CUE not found: $cue_path"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -n "$line" ]] || continue
    [[ "$line" == \;* ]] && continue

    key=${line%%[[:space:]]*}
    rest=${line#"$key"}
    rest="${rest#"${rest%%[![:space:]]*}"}"
    key_u=${key^^}

    case "$key_u" in
      TITLE)
        if ((in_track)); then
          title=$(cue_unquote "$rest")
        else
          album_title=$(cue_unquote "$rest")
        fi
        ;;
      PERFORMER)
        if ((in_track)); then
          performer=$(cue_unquote "$rest")
        else
          album_perf=$(cue_unquote "$rest")
        fi
        ;;
      TRACK)
        if ((in_track)); then
          if [[ -z "$index01" ]]; then
            log_err "Error: TRACK ${track_num:-?} missing INDEX 01 in $cue_path"
            return 1
          fi
          if ! start_sec=$(cue_msf_to_sec "$index01"); then
            log_err "Error: bad INDEX 01 '$index01' in $cue_path"
            return 1
          fi
          idx_nums+=("$track_num")
          titles+=("${title:-$album_title}")
          perfs+=("${performer:-$album_perf}")
          starts+=("$start_sec")
        fi
        track_num=${rest%%[[:space:]]*}
        in_track=1
        title=""
        performer=""
        index01=""
        ;;
      INDEX)
        inum=${rest%%[[:space:]]*}
        itime=${rest#"$inum"}
        itime="${itime#"${itime%%[![:space:]]*}"}"
        if [[ "$inum" == "01" || "$inum" == "1" ]]; then
          index01=$itime
        fi
        ;;
    esac
  done <"$cue_path"

  if ((in_track)); then
    if [[ -z "$index01" ]]; then
      log_err "Error: TRACK ${track_num:-?} missing INDEX 01 in $cue_path"
      return 1
    fi
    if ! start_sec=$(cue_msf_to_sec "$index01"); then
      log_err "Error: bad INDEX 01 '$index01' in $cue_path"
      return 1
    fi
    idx_nums+=("$track_num")
    titles+=("${title:-$album_title}")
    perfs+=("${performer:-$album_perf}")
    starts+=("$start_sec")
  fi

  if ((${#idx_nums[@]} == 0)); then
    log_err "Error: no TRACK entries in CUE: $cue_path"
    return 1
  fi

  for i in "${!idx_nums[@]}"; do
    end_sec=""
    if ((i + 1 < ${#idx_nums[@]})); then
      next_start=${starts[$((i + 1))]}
      end_sec=$next_start
    fi
    # Strip | so pipe-delimited records stay parseable
    printf '%s|%s|%s|%s|%s\n' \
      "${idx_nums[$i]}" \
      "${titles[$i]//|/}" \
      "${perfs[$i]//|/}" \
      "${starts[$i]}" \
      "$end_sec"
  done
}

# Extract [START_SEC, END_SEC) from IMAGE to OUT_WAV via ffmpeg.
# Empty END_SEC means through end of file.
cue_extract_segment() {
  local image="$1" start_sec="$2" end_sec="$3" out_wav="$4"
  local err
  err="$(dirname -- "$out_wav")/cue-extract.err"

  # Place -ss after -i for frame-accurate cuts (slower, correct for CUE splits).
  if [[ -z "$end_sec" ]]; then
    if ! ffmpeg -v error -y -i "$image" -ss "$start_sec" \
      -map 0:a:0 -c:a pcm_s16le "$out_wav" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED cue extract: $image @${start_sec}s → $out_wav"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  else
    if ! ffmpeg -v error -y -i "$image" -ss "$start_sec" -to "$end_sec" \
      -map 0:a:0 -c:a pcm_s16le "$out_wav" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED cue extract: $image @${start_sec}-${end_sec}s → $out_wav"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi
}
