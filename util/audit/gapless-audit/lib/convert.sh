#!/usr/bin/env bash
# Check one file for gapless-playback metadata.

# Print the byte offset of the first MP3 frame (skips an ID3v2 tag).
_gap_mp3_offset() {
  local f=$1
  local -a b=()
  read -r -a b < <(head -c 10 -- "$f" | od -An -tu1 | tr -s ' \n' '  ')
  if ((${#b[@]} >= 10 && b[0] == 73 && b[1] == 68 && b[2] == 51)); then
    # "ID3" + syncsafe size in bytes 6..9
    local size=$(((b[6] & 127) << 21 | (b[7] & 127) << 14 | (b[8] & 127) << 7 | (b[9] & 127)))
    local footer=0
    ((b[5] & 16)) && footer=10
    printf '%d\n' $((10 + size + footer))
  else
    printf '0\n'
  fi
}

_gap_check_mp3() {
  local f=$1 offset window encoder_at b0 b1 b2 delay padding
  local -n _gap_issues=$2
  offset=$(_gap_mp3_offset "$f")
  window=$(dd if="$f" bs=8192 iflag=skip_bytes,count_bytes \
    skip="$offset" count=8192 2>/dev/null | LC_ALL=C tr -c 'A-Za-z' ' ')
  case "$window" in
    *Xing* | *Info*) ;;
    *) _gap_issues+=("no-xing-info-header") ;;
  esac
  case "$window" in
    *LAME* | *Lavc*) ;;
    *) _gap_issues+=("no-lame-tag") ;;
  esac
  encoder_at=$(LC_ALL=C grep -aboE -m1 'LAME|Lavc' -- "$f" 2>/dev/null | cut -d: -f1)
  if [[ "$encoder_at" =~ ^[0-9]+$ ]]; then
    read -r b0 b1 b2 < <(od -An -tu1 -j "$((encoder_at + 21))" -N 3 -- "$f")
    if [[ "$b0" =~ ^[0-9]+$ && "$b1" =~ ^[0-9]+$ && "$b2" =~ ^[0-9]+$ ]]; then
      delay=$((b0 << 4 | b1 >> 4))
      padding=$(((b1 & 15) << 8 | b2))
      if ((delay == 0 && padding == 0)); then
        _gap_issues+=("invalid-delay-padding")
      fi
    else
      _gap_issues+=("invalid-delay-padding")
    fi
  else
    _gap_issues+=("invalid-delay-padding")
  fi
}

_gap_check_m4a() {
  local f=$1 v
  local -n _gap_m4a_issues=$2
  v=$(audio_meta_get "$f" iTunSMPB)
  if [[ -z "$v" ]]; then
    _gap_m4a_issues+=("no-itunsmpb")
  elif ! awk -v value="$v" 'BEGIN {
    n=split(value, a, /[[:space:]]+/); j=0
    for (i=1; i<=n; i++) if (a[i] != "") fields[++j]=a[i]
    if (j < 3) exit 1
    for (i=1; i<=j; i++) if (length(fields[i]) != 8 || fields[i] !~ /^[0-9A-Fa-f]+$/) exit 1
    if (fields[2] == "00000000" && fields[3] == "00000000") exit 1
  }'; then
    _gap_m4a_issues+=("invalid-itunsmpb")
  fi
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
