#!/usr/bin/env bash
# Audit one lossy file: probe, core tags, cover, bitrate floor.

convert_one() {
  local src="$1" issues=() missing=() tag val kbps
  local dir

  dir=$(dirname -- "$src")

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would audit-lossy: $src"; return 0
  fi

  if ! ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 -- "$src" >/dev/null 2>&1; then
    log_fail "$src" "unreadable / no audio stream"
    return 1
  fi

  for tag in ARTIST ALBUM TITLE; do
    val=$(audio_meta_get "$src" "$tag")
    [[ -n "$val" ]] || missing+=("$tag")
  done
  val=$(audio_meta_get "$src" track)
  [[ -n "$val" ]] || val=$(audio_meta_get "$src" TRACKNUMBER)
  [[ -n "$val" ]] || missing+=("TRACK")
  if ((${#missing[@]} > 0)); then
    local IFS=,
    issues+=("missing-tags:${missing[*]}")
  fi

  if ! audio_has_cover "$src"; then
    # folder cover ok
    if ! LC_ALL=C find -P "$dir" -maxdepth 1 -type f \
      \( -iname 'cover.jpg' -o -iname 'folder.jpg' -o -iname 'front.jpg' \) \
      | head -n1 | grep -q .; then
      issues+=("missing-cover")
    fi
  fi

  if kbps=$(audio_bitrate_kbps "$src"); then
    if ((kbps < LOSSY_MIN_KBPS)); then
      issues+=("low-bitrate:${kbps}<${LOSSY_MIN_KBPS}")
    fi
  else
    issues+=("bitrate-unknown")
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$src" "lossy audit issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $src"
  log_success "$src" "clean" "" "$(file_sha256 "$src")" "kbps=${kbps:-?}"
}
