#!/usr/bin/env bash
# DVD CSS helpers (libdvdcss / dvdbackup). No keys or circumvention blobs in-repo.

# Fail closed unless libdvdcss looks available on the system.
dvd_require_css() {
  if au_so_present libdvdcss; then
    return 0
  fi

  # Last resort: ffmpeg DVD demuxer present (still needs libdvdcss at runtime).
  if ffmpeg -hide_banner -demuxers 2>/dev/null | grep -qiE '[[:space:]]dvd($|[[:space:]])'; then
    log_note "note: ffmpeg has dvd demuxer; libdvdcss still required at runtime for CSS discs"
    # Do not treat demuxer alone as success — CSS decrypt needs the library.
  fi

  log_err "Error: libdvdcss not found (needed for encrypted DVD CSS)"
  log_err "  Install distro package libdvdcss (e.g. libdvdcss2 / libdvdcss) and retry"
  log_err "  Arch/CachyOS: libdvdcss   Debian/Ubuntu: libdvdcss2   Fedora: libdvdcss (RPM Fusion)"
  return 1
}

# Default DVD device (config: AUDIO_UTILS_DVD_DEVICE).
dvd_default_device() {
  printf '%s\n' "${AUDIO_UTILS_DVD_DEVICE:-/dev/sr0}"
}

# Backup one DVD title to OUTDIR.
# Prefers dvdbackup when available; otherwise fails with an ffmpeg hint.
# Args: DEVICE_OR_PATH TITLE OUTDIR (device defaults to AUDIO_UTILS_DVD_DEVICE)
dvd_backup_title() {
  local device="${1:-$(dvd_default_device)}" title="$2" outdir="$3"
  local err

  [[ -n "$device" && -n "$title" && -n "$outdir" ]] || {
    log_err "Error: dvd_backup_title requires DEVICE_OR_PATH TITLE OUTDIR"
    return 1
  }

  dvd_require_css || return 1
  mkdir -p -- "$outdir" || return 1
  err="${outdir}/dvdbackup.err"

  if command -v dvdbackup >/dev/null 2>&1; then
    # -t TITLE, -i device/path, -o output directory, -n name prefix
    if ! dvdbackup -i "$device" -t "$title" -o "$outdir" -n "title${title}" \
      >"$err" 2>&1; then
      set_last_err_file "$err"
      log_err "FAILED dvdbackup: device=$device title=$title → $outdir"
      [[ -s "$err" ]] && { log_err "  dvdbackup stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
    log_note "note: dvdbackup completed title=$title → $outdir"
    return 0
  fi

  log_err "Error: dvdbackup not installed (preferred for title backups)"
  log_err "  Install dvdbackup, or copy/decrypt with ffmpeg once CSS is available, e.g.:"
  log_err "    ffmpeg -f dvd -i \"$device\" -map 0:t:${title} -c copy \"${outdir}/title${title}.vob\""
  log_err "  (exact map syntax depends on disc layout; prefer dvdbackup when possible)"
  return 1
}
