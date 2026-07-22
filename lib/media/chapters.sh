#!/usr/bin/env bash
# Chapter list / ffmetadata helpers for M4B/M4A (and other ffmpeg containers).

# Sanitize a chapter title for use as a filename component.
chapters_sanitize_filename() {
  cue_sanitize_filename "$1"
}

# List chapters as: INDEX|START_SEC|END_SEC|TITLE  (1-based index; END may be empty).
chapters_list() {
  local file=$1
  local tmp line rest id field val start end title idx=0 max=-1
  local -A ch_starts=() ch_ends=() ch_titles=()
  [[ -f "$file" ]] || return 1

  tmp=$(mktemp) || return 1
  if ! ffprobe -v error -show_chapters -of flat=s=_ -- "$file" >"$tmp" 2>/dev/null; then
    rm -f -- "$tmp"
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == chapters_chapter_* ]] || continue
    # chapters_chapter_0_start_time=1.234000
    rest=${line#chapters_chapter_}
    id=${rest%%_*}
    field=${rest#*_}
    val=${field#*=}
    field=${field%%=*}
    # flat=s=_ may quote string values: start_time="1.000000"
    if [[ "${val:0:1}" == '"' && "${val: -1}" == '"' && ${#val} -ge 2 ]]; then
      val=${val:1:${#val}-2}
    fi
    case "$field" in
      start_time) ch_starts[$id]=$val ;;
      end_time) ch_ends[$id]=$val ;;
      tags_title) ch_titles[$id]=$val ;;
    esac
    if [[ "$id" =~ ^[0-9]+$ ]] && ((id > max)); then
      max=$id
    fi
  done <"$tmp"
  rm -f -- "$tmp"

  ((max >= 0)) || return 0
  for ((id = 0; id <= max; id++)); do
    start=${ch_starts[$id]:-}
    end=${ch_ends[$id]:-}
    title=${ch_titles[$id]:-}
    [[ -n "$start" ]] || continue
    ((++idx))
    printf '%d|%s|%s|%s\n' "$idx" "$start" "$end" "$title"
  done
}

# Number of chapters (0 if none / unreadable).
chapters_count() {
  local n
  n=$(chapters_list "$1" 2>/dev/null | wc -l | tr -d ' ')
  printf '%s\n' "${n:-0}"
}

# Write ffmetadata from stdin lines: INDEX|START_SEC|END_SEC|TITLE
# TIMEBASE is 1/1000 (milliseconds).
chapters_write_ffmetadata() {
  local out=$1
  local line idx start end title start_ms end_ms
  {
    printf '%s\n' ';FFMETADATA1'
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" ]] || continue
      IFS='|' read -r idx start end title <<<"$line"
      [[ -n "$start" ]] || continue
      start_ms=$(awk -v s="$start" 'BEGIN { printf "%d", (s * 1000) + 0.5 }')
      if [[ -n "$end" ]]; then
        end_ms=$(awk -v s="$end" 'BEGIN { printf "%d", (s * 1000) + 0.5 }')
      else
        end_ms=$start_ms
      fi
      # Escape special ffmetadata chars: = ; # \
      title=${title//\\/\\\\}
      title=${title//=/\\=}
      title=${title//;/\';}
      title=${title//#/\\#}
      printf '%s\n' '[CHAPTER]'
      printf '%s\n' 'TIMEBASE=1/1000'
      printf 'START=%s\n' "$start_ms"
      printf 'END=%s\n' "$end_ms"
      printf 'title=%s\n' "$title"
    done
  } >"$out"
}

# Extract chapters from media to an ffmetadata file. Returns 1 if none.
chapters_extract() {
  local file=$1 out=$2
  local tmp n
  tmp=$(mktemp) || return 1
  if ! chapters_list "$file" >"$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  n=$(wc -l <"$tmp" | tr -d ' ')
  if [[ "${n:-0}" -eq 0 ]]; then
    rm -f -- "$tmp"
    return 1
  fi
  chapters_write_ffmetadata "$out" <"$tmp"
  rm -f -- "$tmp"
  return 0
}

# Embed ffmetadata chapters into SRC → DEST (stream copy).
chapters_embed() {
  local src=$1 dest=$2 ffmeta=$3
  local err
  err="$(dirname -- "$dest")/chapters.embed.err"
  # Use -f mp4 (ipod rejects some chapter/metadata combos). Map chapters only;
  # keep container metadata from the source (-map_metadata 0).
  if ! ffmpeg -v error -y -i "$src" -i "$ffmeta" \
    -map 0 -map_metadata 0 -map_chapters 1 -c copy -f mp4 \
    -- "$dest" 2>"$err"; then
    set_last_err_file "$err" 2>/dev/null || true
    return 1
  fi
  return 0
}

# Build chapter list lines from ordered duration_sec|title pairs on stdin.
# Prints INDEX|START_SEC|END_SEC|TITLE (cumulative).
chapters_from_durations() {
  local line dur title start=0 end idx=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    dur=${line%%|*}
    title=${line#*|}
    [[ "$dur" =~ ^[0-9]+([.][0-9]+)?$ ]] || continue
    end=$(awk -v a="$start" -v b="$dur" 'BEGIN { printf "%.8f", a + b }')
    ((++idx))
    printf '%d|%s|%s|%s\n' "$idx" "$start" "$end" "$title"
    start=$end
  done
}

# Write ffmetadata from duration_sec|title pairs on stdin.
chapters_ffmetadata_from_durations() {
  local out=$1
  local tmp
  tmp=$(mktemp) || return 1
  chapters_from_durations >"$tmp"
  chapters_write_ffmetadata "$out" <"$tmp"
  rm -f -- "$tmp"
}

# Build chapter list from a CUE sheet (INDEX|START|END|TITLE). Uses cue_list_tracks.
chapters_from_cue() {
  local cue=$1
  local line idx title start_sec end_sec out_idx=0
  local -a tracks=()
  mapfile -t tracks < <(cue_list_tracks "$cue") || return 1
  ((${#tracks[@]} > 0)) || return 1
  for line in "${tracks[@]}"; do
    IFS='|' read -r idx title _ start_sec end_sec <<<"$line"
    ((++out_idx))
    printf '%d|%s|%s|%s\n' "$out_idx" "$start_sec" "${end_sec:-}" "${title:-}"
  done
}

# Write ffmetadata from a CUE sheet.
chapters_ffmetadata_from_cue() {
  local cue=$1 out=$2
  local tmp
  tmp=$(mktemp) || return 1
  if ! chapters_from_cue "$cue" >"$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  chapters_write_ffmetadata "$out" <"$tmp"
  rm -f -- "$tmp"
}

# True if codec name is a supported M4B audio codec (aac / opus / alac).
chapters_m4b_codec_ok() {
  case "${1,,}" in
    aac|opus|alac|mp4a*) return 0 ;;
    *) return 1 ;;
  esac
}
