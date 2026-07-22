#!/usr/bin/env bash
# Recompress one FLAC at the configured level; preserve tags + pictures.

convert_one() {
  local flac="$1"
  local dir tmpdir raw tagged md5_before md5_after
  local before_bytes after_bytes sha notes=""

  dir=$(dirname -- "$flac")

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would optimize (-${OPT_LEVEL:-8}): $flac"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  before_bytes=$(file_bytes "$flac")
  md5_before=$(metaflac --show-md5sum -- "$flac" 2>/dev/null || true)
  md5_before=${md5_before,,}
  if [[ -z "$md5_before" || "$md5_before" == "00000000000000000000000000000000" ]]; then
    md5_before=$(audio_md5 "$flac") || true
  fi
  if [[ -z "$md5_before" ]]; then
    log_fail "$flac" "could not read audio MD5"
    return 1
  fi

  tmpdir=$(make_workdir "$dir")
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  raw="${tmpdir}/raw.flac"
  tagged="${tmpdir}/tagged.flac"

  if ! flac -d --silent -o "${tmpdir}/audio.wav" -- "$flac" 2>"${tmpdir}/dec.err"; then
    set_last_err_file "${tmpdir}/dec.err"
    log_fail "$flac" "decode failed"
    cleanup
    return 1
  fi

  if ! flac -f -"${OPT_LEVEL}" --no-padding --silent \
    -o "$raw" "${tmpdir}/audio.wav" 2>"${tmpdir}/enc.err"; then
    set_last_err_file "${tmpdir}/enc.err"
    log_fail "$flac" "encode failed" "level=$OPT_LEVEL"
    cleanup
    return 1
  fi

  md5_after=$(metaflac --show-md5sum -- "$raw" 2>/dev/null || true)
  md5_after=${md5_after,,}
  if [[ "$md5_after" != "$md5_before" ]]; then
    local dec_a dec_b
    dec_a=$(audio_md5 "$flac") || true
    dec_b=$(audio_md5 "$raw") || true
    if [[ -z "$dec_a" || "$dec_a" != "$dec_b" ]]; then
      log_fail "$flac" "audio MD5 mismatch after optimize" \
        "before=$md5_before after=$md5_after"
      cleanup
      return 1
    fi
    notes="verified-decode-md5"
  else
    notes="streaminfo-md5-ok"
  fi

  if ! tag_flac_from_source "$flac" "$raw" "$tagged"; then
    log_fail "$flac" "restore tags/cover failed"
    cleanup
    return 1
  fi

  if ! flac_ok "$tagged"; then
    log_fail "$flac" "optimized flac -t failed"
    cleanup
    return 1
  fi

  after_bytes=$(file_bytes "$tagged")
  if [[ "$after_bytes" -ge "$before_bytes" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (no size win): $flac ($before_bytes -> $after_bytes)"
    log_success "$flac" "skipped" "$md5_before" "$(file_sha256 "$flac")" \
      "no-shrink;${notes}"
    cleanup
    return 0
  fi

  if ! mv -f -- "$tagged" "$flac"; then
    log_fail "$flac" "replace failed"
    cleanup
    return 1
  fi
  cleanup

  sha=$(file_sha256 "$flac")
  log_progress "optimized: $flac ($before_bytes -> $after_bytes)"
  log_success "$flac" "flac-$OPT_LEVEL" "$md5_before" "$sha" \
    "bytes:${before_bytes}->${after_bytes};${notes}"
}
