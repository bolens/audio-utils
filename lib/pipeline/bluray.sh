#!/usr/bin/env bash
# Blu-ray AACS/BD+ helpers. No keys, KEYDB, or BD+ dumps in-repo — operator supplies them.

# True if NAME.so* appears via ldconfig or common lib paths.
_bluray_so_present() {
  au_so_present "$1"
}

bluray_libbluray_present() { _bluray_so_present libbluray; }
bluray_libaacs_present() { _bluray_so_present libaacs; }
bluray_libbdplus_present() { _bluray_so_present libbdplus; }

# Fail closed unless libbluray + libaacs look available.
bluray_require_libs() {
  local ok=1
  if ! bluray_libbluray_present; then
    log_err "Error: libbluray not found (needed for Blu-ray / BDMV)"
    ok=0
  fi
  if ! bluray_libaacs_present; then
    log_err "Error: libaacs not found (needed for AACS-encrypted discs)"
    ok=0
  fi
  if ((ok == 0)); then
    log_err "  Arch/CachyOS: libbluray libaacs (libbdplus optional for BD+)"
    log_err "  Debian/Ubuntu: libbluray2 libaacs0 (libbdplus0 optional)"
    log_err "  Fedora: libbluray libaacs (RPM Fusion for some extras)"
    log_err "  This project does not ship AACS keys or BD+ dumps - see docs/discs.md"
    return 1
  fi
  if ! bluray_libbdplus_present; then
    log_note "note: libbdplus not found; BD+-protected titles may need MakeMKV or libbdplus + operator dumps"
  fi
  return 0
}

# Print candidate KEYDB.cfg paths (one per line); does not create or fetch keys.
bluray_keydb_candidates() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/aacs"
  local f
  for f in KEYDB.cfg keydb.cfg KeyDB.cfg KEYDB.CFG; do
    printf '%s\n' "${cfg}/${f}"
  done
}

# True if an operator-supplied KEYDB.cfg exists.
bluray_keydb_present() {
  local p
  while IFS= read -r p; do
    [[ -f "$p" && -s "$p" ]] && return 0
  done < <(bluray_keydb_candidates)
  return 1
}

bluray_keydb_hint() {
  local first
  first=$(bluray_keydb_candidates | head -n1)
  log_err "  Place operator-supplied KEYDB.cfg at: $first"
  log_err "  (audio-utils never downloads or vendors AACS keys)"
}

# Resolve MakeMKV CLI: AUDIO_UTILS_MAKEMKV or makemkvcon on PATH.
bluray_makemkv_bin() {
  local bin="${AUDIO_UTILS_MAKEMKV:-}"
  if [[ -n "$bin" && -x "$bin" ]]; then
    printf '%s\n' "$bin"
    return 0
  fi
  if command -v makemkvcon >/dev/null 2>&1; then
    command -v makemkvcon
    return 0
  fi
  return 1
}

# Resolve BDMV directory from PATH (BDMV itself, parent with BDMV/, or STREAM parent).
bluray_resolve_bdmv() {
  local path="$1"
  if [[ -d "$path" && "$(basename -- "$path")" == "BDMV" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  if [[ -d "$path/BDMV" ]]; then
    printf '%s\n' "$path/BDMV"
    return 0
  fi
  if [[ -d "$path" && "$(basename -- "$path")" == "STREAM" ]]; then
    printf '%s\n' "$(dirname -- "$path")"
    return 0
  fi
  return 1
}

# Disc root containing BDMV (parent of BDMV).
bluray_disc_root() {
  local bdmv
  bdmv=$(bluray_resolve_bdmv "$1") || return 1
  dirname -- "$bdmv"
}

# Default Blu-ray device.
bluray_default_device() {
  printf '%s\n' "${AUDIO_UTILS_BD_DEVICE:-/dev/sr0}"
}

# True if ffprobe sees at least one audio stream (already readable / decrypted).
bluray_media_readable() {
  local f="$1" n
  [[ -f "$f" ]] || return 1
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$f" 2>/dev/null | grep -c . || true)
  ((n >= 1))
}

# List decrypted-looking media under DIR (m2ts/mkv/mka/mp4), one path per line.
bluray_list_plain_media() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  LC_ALL=C find -P "$dir" -maxdepth 3 -type f \
    \( -iname '*.m2ts' -o -iname '*.mkv' -o -iname '*.mka' -o -iname '*.mp4' \) \
    2>/dev/null | LC_ALL=C sort
}

# List STREAM/*.m2ts under BDMV (or disc root).
bluray_list_stream_m2ts() {
  local bdmv stream
  bdmv=$(bluray_resolve_bdmv "$1") || return 1
  stream="${bdmv}/STREAM"
  [[ -d "$stream" ]] || return 1
  LC_ALL=C find -P "$stream" -maxdepth 1 -type f -iname '*.m2ts' 2>/dev/null | LC_ALL=C sort
}

# Classify INPUT: device | bdmv | media_file | media_dir | unknown
# Prints kind on stdout.
bluray_resolve_input() {
  local path="$1"
  if [[ -b "$path" || ( -e "$path" && "$path" == /dev/* ) ]]; then
    printf '%s\n' device
    return 0
  fi
  if [[ -f "$path" ]]; then
    case "${path,,}" in
      *.m2ts|*.mkv|*.mka|*.mp4|*.ts)
        printf '%s\n' media_file
        return 0
        ;;
    esac
    printf '%s\n' unknown
    return 1
  fi
  if [[ -d "$path" ]]; then
    if bluray_resolve_bdmv "$path" >/dev/null; then
      printf '%s\n' bdmv
      return 0
    fi
    if bluray_list_plain_media "$path" | head -n1 | grep -q .; then
      printf '%s\n' media_dir
      return 0
    fi
    printf '%s\n' unknown
    return 1
  fi
  printf '%s\n' unknown
  return 1
}

# Attempt MakeMKV backup of DEVICE_OR_DISC to OUTDIR (mkv files).
# Args: SOURCE OUTDIR
bluray_makemkv_backup() {
  local src="$1" outdir="$2" bin err
  bin=$(bluray_makemkv_bin) || {
    log_err "Error: MakeMKV (makemkvcon) not found"
    log_err "  Install MakeMKV or set AUDIO_UTILS_MAKEMKV=/path/to/makemkvcon"
    return 1
  }
  mkdir -p -- "$outdir" || return 1
  err="${outdir}/makemkv.err"
  # mkv output; disc path or device. -r robot mode, --minlength filter short clips.
  if ! "$bin" mkv "$src" all "$outdir" --minlength=0 >"$err" 2>&1; then
    # Some builds want disc:prefix
    if ! "$bin" mkv "disc:$src" all "$outdir" --minlength=0 >"$err" 2>&1; then
      set_last_err_file "$err"
      log_err "FAILED makemkvcon: $src -> $outdir"
      [[ -s "$err" ]] && { log_err "  makemkv stderr:"; sed 's/^/  | /' "$err" | head -n 40 >&2; }
      return 1
    fi
  fi
  log_note "note: MakeMKV backup completed -> $outdir"
  return 0
}

# Try ffmpeg bluray protocol / libbluray demux of disc root to OUT_MKV (first playlist).
# Best-effort; many builds need KEYDB + libs. Args: DISC_ROOT OUT_MKV
bluray_ffmpeg_bluray_copy() {
  local disc="$1" out_mkv="$2" err
  err="$(dirname -- "$out_mkv")/ffmpeg-bluray.err"
  mkdir -p -- "$(dirname -- "$out_mkv")" || return 1

  # bluray: protocol (libbluray). Playlist -1 = longest / default.
  if ffmpeg -hide_banner -protocols 2>/dev/null | grep -qi bluray; then
    if ffmpeg -v error -y -f bluray -i "$disc" -map 0:a -c copy "$out_mkv" 2>"$err"; then
      return 0
    fi
  fi
  # Fallback: open BDMV path as directory input when demuxer supports it.
  if ffmpeg -v error -y -i "$disc" -map 0:a -c copy "$out_mkv" 2>"$err"; then
    return 0
  fi
  set_last_err_file "$err"
  return 1
}

# Hybrid: produce readable media under OUTDIR for SRC (device/BDMV/plain).
# Prints paths of media files to process (one per line) on stdout.
# On encrypted disc without tooling/KEYDB: fail closed with specific hints.
bluray_decrypt_or_copy() {
  local src="$1" outdir="$2"
  local kind bdmv disc readable=0 f first

  [[ -n "$src" && -n "$outdir" ]] || {
    log_err "Error: bluray_decrypt_or_copy requires SRC OUTDIR"
    return 1
  }
  mkdir -p -- "$outdir" || return 1

  kind=$(bluray_resolve_input "$src" 2>/dev/null) || kind=unknown

  case "$kind" in
    media_file)
      if bluray_media_readable "$src"; then
        printf '%s\n' "$src"
        return 0
      fi
      log_err "Error: media not readable (encrypted or corrupt): $src"
      return 1
      ;;
    media_dir)
      while IFS= read -r f; do
        if bluray_media_readable "$f"; then
          printf '%s\n' "$f"
          readable=1
        fi
      done < <(bluray_list_plain_media "$src")
      if ((readable)); then
        return 0
      fi
      log_err "Error: no readable media under $src"
      return 1
      ;;
    bdmv)
      bdmv=$(bluray_resolve_bdmv "$src") || return 1
      disc=$(dirname -- "$bdmv")
      while IFS= read -r f; do
        if bluray_media_readable "$f"; then
          printf '%s\n' "$f"
          readable=1
        fi
      done < <(bluray_list_stream_m2ts "$bdmv")
      if ((readable)); then
        log_note "note: using already-readable STREAM m2ts under $bdmv"
        return 0
      fi
      # Encrypted path — try open libs + KEYDB, then MakeMKV.
      if bluray_require_libs && bluray_keydb_present; then
        first="${outdir}/bluray-audio.mkv"
        if bluray_ffmpeg_bluray_copy "$disc" "$first" && bluray_media_readable "$first"; then
          printf '%s\n' "$first"
          return 0
        fi
        log_note "note: ffmpeg/libbluray path failed; trying MakeMKV if available"
      elif ! bluray_keydb_present; then
        log_err "Error: BDMV streams not readable and KEYDB.cfg missing"
        bluray_keydb_hint
        if bluray_makemkv_bin >/dev/null; then
          log_note "note: MakeMKV found - attempting backup without KEYDB"
        else
          log_err "  Or supply already-decrypted M2TS/MKV, or install MakeMKV (AUDIO_UTILS_MAKEMKV)"
          log_err "  BD+ titles often need MakeMKV or libbdplus + operator dumps (docs/discs.md)"
          return 1
        fi
      fi
      if bluray_makemkv_bin >/dev/null; then
        if bluray_makemkv_backup "$disc" "$outdir"; then
          while IFS= read -r f; do
            bluray_media_readable "$f" && printf '%s\n' "$f"
          done < <(bluray_list_plain_media "$outdir")
          return 0
        fi
      fi
      log_err "Error: cannot decrypt BDMV at $bdmv"
      log_err "  Install libbluray+libaacs (+ KEYDB.cfg) and/or MakeMKV, or use decrypted media"
      if ! bluray_libbdplus_present; then
        log_err "  If this disc uses BD+: install libbdplus + dumps, or use MakeMKV"
      fi
      return 1
      ;;
    device)
      if bluray_makemkv_bin >/dev/null; then
        if bluray_makemkv_backup "$src" "$outdir"; then
          while IFS= read -r f; do
            bluray_media_readable "$f" && printf '%s\n' "$f"
          done < <(bluray_list_plain_media "$outdir")
          return 0
        fi
        return 1
      fi
      if bluray_require_libs && bluray_keydb_present; then
        first="${outdir}/bluray-audio.mkv"
        if bluray_ffmpeg_bluray_copy "$src" "$first" && bluray_media_readable "$first"; then
          printf '%s\n' "$first"
          return 0
        fi
      fi
      log_err "Error: cannot read Blu-ray device $src"
      log_err "  Install MakeMKV (preferred for devices) or libbluray+libaacs with KEYDB.cfg"
      bluray_keydb_hint
      return 1
      ;;
    *)
      log_err "Error: unrecognized Blu-ray input: $src"
      log_err "  Expect BDMV tree, device (/dev/srN), or decrypted .m2ts/.mkv directory"
      return 1
      ;;
  esac
}
