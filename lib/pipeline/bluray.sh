#!/usr/bin/env bash
# Blu-ray title transport. MakeMKV handles playlist resolution and any
# decryption it supports; audio-utils never supplies keys or protection data.

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

# True if ffprobe sees at least one audio stream (already readable / decrypted).
bluray_media_readable() {
  local f="$1" n
  [[ -f "$f" ]] || return 1
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$f" 2>/dev/null | grep -c . || true)
  ((n >= 1))
}

# List decrypted-looking media under DIR (m2ts/mkv/mka/mp4).
# Pass --print0 for NUL-delimited output.
bluray_list_plain_media() {
  local print0=0
  if [[ ${1:-} == --print0 ]]; then
    print0=1
    shift
  fi
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  local -a args=(-P "$dir" -maxdepth 3 -type f
    \( -iname '*.m2ts' -o -iname '*.mkv' -o -iname '*.mka' -o -iname '*.mp4' -o -iname '*.ts' \))
  if ((print0)); then
    LC_ALL=C find "${args[@]}" -print0 2>/dev/null | LC_ALL=C sort -z
  else
    LC_ALL=C find "${args[@]}" 2>/dev/null | LC_ALL=C sort
  fi
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
    if LC_ALL=C find -P "$path" -maxdepth 3 -type f \
      \( -iname '*.m2ts' -o -iname '*.mkv' -o -iname '*.mka' -o -iname '*.mp4' -o -iname '*.ts' \) \
      -print -quit 2>/dev/null | grep -q .; then
      printf '%s\n' media_dir
      return 0
    fi
    printf '%s\n' unknown
    return 1
  fi
  printf '%s\n' unknown
  return 1
}

# Convert a device or BDMV tree to MakeMKV's explicit source syntax.
bluray_makemkv_source() {
  local src="$1" bdmv disc
  if [[ "$src" == dev:* || "$src" == disc:* || "$src" == file:* || "$src" == iso:* ]]; then
    printf '%s\n' "$src"
  elif [[ -b "$src" || "$src" == /dev/* ]]; then
    printf 'dev:%s\n' "$src"
  elif bdmv=$(bluray_resolve_bdmv "$src" 2>/dev/null); then
    disc=$(dirname -- "$bdmv")
    printf 'file:%s\n' "$disc"
  elif [[ -f "$src" && "${src,,}" == *.iso ]]; then
    printf 'iso:%s\n' "$src"
  else
    return 1
  fi
}

# Extract authored titles from DEVICE_OR_DISC to OUTDIR (mkv files).
# Args: SOURCE OUTDIR
bluray_makemkv_backup() {
  local src="$1" outdir="$2" bin err source
  bin=$(bluray_makemkv_bin) || {
    log_err "Error: MakeMKV (makemkvcon) not found"
    log_err "  Install MakeMKV or set AUDIO_UTILS_MAKEMKV=/path/to/makemkvcon"
    return 1
  }
  source=$(bluray_makemkv_source "$src") || {
    log_err "Error: unsupported MakeMKV source: $src"
    return 1
  }
  mkdir -p -- "$outdir" || return 1
  err="${outdir}/makemkv.err"
  if ! "$bin" --robot --minlength=0 mkv "$source" all "$outdir" >"$err" 2>&1; then
    set_last_err_file "$err"
    log_err "FAILED makemkvcon: $source -> $outdir"
    [[ -s "$err" ]] && { log_err "  makemkv stderr:"; sed 's/^/  | /' "$err" | head -n 40 >&2; }
    return 1
  fi
  log_note "note: MakeMKV backup completed -> $outdir"
  return 0
}

# Hybrid: produce readable media under OUTDIR for SRC (device/BDMV/plain).
# Prints paths of media files to process as NUL-delimited records on stdout.
# On encrypted disc without tooling/KEYDB: fail closed with specific hints.
bluray_decrypt_or_copy() {
  local src="$1" outdir="$2"
  local kind bdmv disc readable=0 f

  [[ -n "$src" && -n "$outdir" ]] || {
    log_err "Error: bluray_decrypt_or_copy requires SRC OUTDIR"
    return 1
  }
  mkdir -p -- "$outdir" || return 1

  kind=$(bluray_resolve_input "$src" 2>/dev/null) || kind=unknown

  case "$kind" in
    media_file)
      if bluray_media_readable "$src"; then
        printf '%s\0' "$src"
        return 0
      fi
      log_err "Error: media not readable (encrypted or corrupt): $src"
      return 1
      ;;
    media_dir)
      while IFS= read -r -d '' f; do
        if bluray_media_readable "$f"; then
          printf '%s\0' "$f"
          readable=1
        fi
      done < <(bluray_list_plain_media --print0 "$src")
      if ((readable)); then
        return 0
      fi
      log_err "Error: no readable media under $src"
      return 1
      ;;
    bdmv)
      bdmv=$(bluray_resolve_bdmv "$src") || return 1
      disc=$(dirname -- "$bdmv")
      if bluray_makemkv_bin >/dev/null; then
        if bluray_makemkv_backup "$disc" "$outdir"; then
          while IFS= read -r -d '' f; do
            bluray_media_readable "$f" && printf '%s\0' "$f"
          done < <(bluray_list_plain_media --print0 "$outdir")
          return 0
        fi
      fi
      log_err "Error: cannot resolve authored Blu-ray titles at $bdmv"
      log_err "  Install MakeMKV, or pass standalone decrypted M2TS/MKV files"
      log_err "  Raw BDMV/STREAM clips are not titles and are intentionally not extracted"
      return 1
      ;;
    device)
      if bluray_makemkv_bin >/dev/null; then
        if bluray_makemkv_backup "$src" "$outdir"; then
          while IFS= read -r -d '' f; do
            bluray_media_readable "$f" && printf '%s\0' "$f"
          done < <(bluray_list_plain_media --print0 "$outdir")
          return 0
        fi
        return 1
      fi
      log_err "Error: cannot read Blu-ray device $src"
      log_err "  Install MakeMKV to resolve and decrypt authored titles"
      return 1
      ;;
    *)
      log_err "Error: unrecognized Blu-ray input: $src"
      log_err "  Expect BDMV tree, device (/dev/srN), or decrypted .m2ts/.mkv directory"
      return 1
      ;;
  esac
}
