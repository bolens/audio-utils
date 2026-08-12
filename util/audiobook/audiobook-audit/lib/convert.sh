#!/usr/bin/env bash
# Audit one audiobook unit (.m4b file or multi-file chapter directory).

_aba_list_audio() {
  local dir=$1 ext
  local -a find_args=( -P "$dir" -maxdepth 1 -type f \( )
  local first=1
  # shellcheck disable=SC2086
  for ext in ${AU_SOURCE_EXTS:-m4b m4a mp3 flac}; do
    if [[ "$first" -eq 1 ]]; then
      find_args+=( -iname "*.${ext}" ); first=0
    else
      find_args+=( -o -iname "*.${ext}" )
    fi
  done
  find_args+=( \) -print0 )
  LC_ALL=C find "${find_args[@]}" | LC_ALL=C sort -z
}

# Print semicolon-joined issues (empty = clean). Arg: path to .m4b OR directory.
_aba_audit_unit() {
  local unit=$1
  local -a issues=() files=()
  local f title artist narrator series series_part codec n track num total rate
  local -A series_seen=() rates=() tracks_seen=() totals_seen=()
  local missing_title=0 missing_track=0 duplicate_track=0 max_track=0

  if [[ -f "$unit" ]]; then
    case "${unit,,}" in
      *.m4b)
        audio_decode_ok "$unit" || issues+=("audio-decode-failed")
        title=$(audio_meta_get "$unit" TITLE)
        [[ -n "$title" ]] || title=$(audio_meta_get "$unit" ALBUM)
        [[ -n "$title" ]] || issues+=("missing-title")
        artist=$(audio_meta_get "$unit" ALBUMARTIST)
        [[ -n "$artist" ]] || artist=$(audio_meta_get "$unit" ARTIST)
        [[ -n "$artist" ]] || issues+=("missing-author")
        narrator=$(audio_meta_get "$unit" NARRATOR)
        [[ -n "$narrator" ]] || issues+=("missing-narrator")
        audio_valid_cover "$unit" || issues+=("missing-or-invalid-cover")
        n=$(chapters_count "$unit" 2>/dev/null || echo 0)
        if [[ "${n:-0}" -eq 0 ]]; then
          issues+=("no-chapters")
        elif [[ "$n" -eq 1 ]]; then
          issues+=("single-trivial-chapter")
        fi
        codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
          -of csv=p=0 -- "$unit" 2>/dev/null || true)
        if [[ -n "$codec" ]] && ! chapters_m4b_codec_ok "$codec"; then
          issues+=("unexpected-codec:${codec}")
        fi
        series=$(audio_meta_get "$unit" SERIES)
        series_part=$(audio_meta_get "$unit" SERIES-PART)
        [[ -n "$series_part" ]] || series_part=$(audio_meta_get "$unit" SERIESPART)
        if [[ -n "$series" && -z "$series_part" ]]; then
          issues+=("series-without-part")
        fi
        ;;
      *)
        issues+=("not-m4b")
        ;;
    esac
  else
    au_mapfile0 files < <(_aba_list_audio "$unit")
    # Prefer treating a lone .m4b in the dir as the book unit
    local m4b_only=()
    for f in "${files[@]}"; do
      case "${f,,}" in *.m4b) m4b_only+=("$f") ;; esac
    done
    if ((${#m4b_only[@]} == 1)) && ((${#files[@]} == 1)); then
      _aba_audit_unit "${m4b_only[0]}"
      return
    fi
    if ((${#files[@]} == 0)); then
      printf '\n'
      return 0
    fi
    for f in "${files[@]}"; do
      case "${f,,}" in *.m4b) continue ;; esac
      audio_decode_ok "$f" || issues+=("audio-decode-failed")
      title=$(audio_meta_get "$f" TITLE)
      [[ -n "$title" ]] || ((missing_title++)) || true
      artist=$(audio_meta_get "$f" ALBUMARTIST)
      [[ -n "$artist" ]] || artist=$(audio_meta_get "$f" ARTIST)
      [[ -n "$artist" ]] || issues+=("missing-author")
      narrator=$(audio_meta_get "$f" NARRATOR)
      [[ -n "$narrator" ]] || issues+=("missing-narrator")
      series=$(audio_meta_get "$f" SERIES)
      [[ -z "$series" ]] || series_seen["$series"]=1
      series_part=$(audio_meta_get "$f" SERIES-PART)
      [[ -n "$series_part" ]] || series_part=$(audio_meta_get "$f" SERIESPART)
      if [[ -n "$series" && -z "$series_part" ]]; then
        issues+=("series-without-part")
      fi
      rate=$(audio_sample_rate "$f" 2>/dev/null || true)
      [[ -z "$rate" ]] || rates["$rate"]=1
      track=$(audio_meta_get "$f" TRACKNUMBER)
      [[ -n "$track" ]] || track=$(audio_meta_get "$f" track)
      if [[ "$track" == */* ]]; then
        total=${track#*/}
        [[ "$total" =~ ^[0-9]+$ && $((10#$total)) -gt 0 ]] && totals_seen[$((10#$total))]=1 \
          || issues+=("invalid-track-total")
      fi
      track=${track%%/*}
      if [[ "$track" =~ ^[0-9]+$ ]]; then
        num=$((10#$track))
        if [[ -n "${tracks_seen[$num]:-}" ]]; then
          ((duplicate_track++)) || true
        fi
        tracks_seen[$num]=1
        ((num > max_track)) && max_track=$num
      else
        ((missing_track++)) || true
      fi
    done
    # Deduplicate issue labels that may repeat per file
    local -A uniq=()
    local -a deduped=()
    local i
    for i in "${issues[@]}"; do
      [[ -z "${uniq[$i]:-}" ]] || continue
      uniq[$i]=1
      deduped+=("$i")
    done
    issues=("${deduped[@]}")

    audio_valid_cover "${files[0]}" || issues+=("missing-or-invalid-cover")
    ((missing_title > 0)) && issues+=("empty-titles:$missing_title")
    ((missing_track > 0)) && issues+=("missing-tracknumbers:$missing_track")
    ((duplicate_track > 0)) && issues+=("duplicate-tracknumbers:$duplicate_track")
    total=${#tracks_seen[@]}
    if ((total > 0)) && { ((max_track != total)) || [[ -z "${tracks_seen[1]:-}" ]]; }; then
      issues+=("track-gaps:${total}/${max_track}")
    fi
    if ((${#totals_seen[@]} > 1)); then
      issues+=("mismatched-track-totals")
    elif ((${#totals_seen[@]} == 1)); then
      for n in "${!totals_seen[@]}"; do
        ((n == total)) || issues+=("declared-track-total:${n}/${total}")
      done
    fi
    if ((${#rates[@]} > 1)); then
      issues+=("mixed-sample-rates")
    fi
    if ((${#series_seen[@]} > 1)); then
      issues+=("mismatched-series")
    fi
  fi

  if ((${#issues[@]})); then
    local IFS=';'
    printf '%s\n' "${issues[*]}"
  else
    printf '\n'
  fi
}

convert_one() {
  local src="$1" dir key result_f issues n unit

  case "${src,,}" in
    *.m4b)
      unit=$(au_abspath "$src")
      dir=$(dirname -- "$unit")
      ;;
    *)
      dir=$(cd -- "$(dirname -- "$src")" && pwd) || {
        log_fail "$src" "cannot resolve directory"
        return 1
      }
      unit=$dir
      ;;
  esac

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would audiobook-audit: $unit"
    return 0
  fi

  key=$(au_sha256_str "$unit")
  if ! mkdir -- "${AU_ABAUDIT_STATE:?}/${key}.claim" 2>/dev/null; then
    log_progress "covered by unit audit: $src"
    log_success "$src" "skip" "" "" "unit-covered"
    return 0
  fi

  result_f="${AU_ABAUDIT_STATE}/${key}.result"
  (
    flock 9
    _aba_audit_unit "$unit" >"$result_f"
  ) 9>"${AU_ABAUDIT_STATE}/${key}.lock"

  issues=$(head -n1 -- "$result_f" 2>/dev/null || true)

  if [[ -f "$unit" ]]; then
    n=1
  else
    n=$(_aba_list_audio "$unit" | tr -cd '\0' | wc -c | tr -d ' ')
  fi

  if [[ -n "$issues" ]]; then
    log_fail "$unit" "audiobook audit issues" "$issues"
    return 1
  fi

  log_progress "ok: $unit (files=$n)"
  log_success "$unit" "clean" "" "" "files=$n"
}
