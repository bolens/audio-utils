#!/usr/bin/env bash
# Check one file for gapless-playback metadata.

# Print the byte offset of the first MP3 frame (skips an ID3v2 tag).
_gap_mp3_offset() {
  local f=$1
  local -a b=()
  read -r -a b < <(head -c 10 -- "$f" | od -An -tu1 | tr -s ' \n' '  ')
  if ((${#b[@]} >= 10 && b[0] == 73 && b[1] == 68 && b[2] == 51)); then
    # "ID3" + syncsafe size in bytes 6..9
    printf '%d\n' $((10 + ((b[6] & 127) << 21 | (b[7] & 127) << 14 | (b[8] & 127) << 7 | (b[9] & 127))))
  else
    printf '0\n'
  fi
}

_gap_check_mp3() {
  local f=$1 offset window
  local -n _gap_issues=$2
  offset=$(_gap_mp3_offset "$f")
  window=$(dd if="$f" bs=8192 iflag=skip_bytes,count_bytes \
    skip="$offset" count=8192 2>/dev/null | LC_ALL=C tr -c 'A-Za-z' ' ')
  case "$window" in
    *Xing* | *Info*) ;;
    *) _gap_issues+=("no-xing-info-header") ;;
  esac
  case "$window" in
    *LAME* | *Lavc* | *Lavf*) ;;
    *) _gap_issues+=("no-lame-tag") ;;
  esac
}

_gap_check_m4a() {
  local f=$1 v
  local -n _gap_m4a_issues=$2
  v=$(audio_meta_get "$f" iTunSMPB)
  [[ -n "$v" ]] || _gap_m4a_issues+=("no-itunsmpb")
}

convert_one() {
  local f="$1"
  local -a issues=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would gapless-check: $f"; return 0
  fi

  case "${f,,}" in
    *.mp3) _gap_check_mp3 "$f" issues ;;
    *.m4a) _gap_check_m4a "$f" issues ;;
    *.aac) issues+=("adts-no-gapless-metadata") ;;
  esac

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$f" "gapless metadata issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $f"
  log_success "$f" "clean" "" "" "gapless-ok"
}
