#!/usr/bin/env bash
# Verify one FLAC: flac -t, optional ffmpeg decode MD5 vs STREAMINFO.

convert_one() {
  local flac="$1"
  local md5="" sha="" mode=test notes="" stream_md5 decoded_md5

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if [[ "${VERIFY_MD5:-0}" -eq 1 ]]; then
      log_progress "would verify+md5: $flac"
    else
      log_progress "would verify: $flac"
    fi
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$flac" "flac -t failed"
    return 1
  fi

  mode="test"
  if [[ "${VERIFY_MD5:-0}" -eq 1 ]]; then
    mode="test+md5"
    decoded_md5=$(audio_md5 "$flac") || true
    if [[ -z "$decoded_md5" ]]; then
      log_fail "$flac" "decode MD5 failed"
      return 1
    fi
    md5=$decoded_md5

    stream_md5=$(metaflac --show-md5sum -- "$flac" 2>/dev/null || true)
    stream_md5=${stream_md5,,}
    if [[ -n "$stream_md5" && "$stream_md5" != "00000000000000000000000000000000" ]]; then
      if [[ "$stream_md5" != "$decoded_md5" ]]; then
        log_fail "$flac" "STREAMINFO MD5 != decode MD5" \
          "stream=$stream_md5 decode=$decoded_md5"
        return 1
      fi
      notes="streaminfo-md5-ok"
    else
      notes="no-streaminfo-md5"
    fi
  fi

  sha=$(file_sha256 "$flac")
  log_progress "ok: $flac"
  log_success "$flac" "$mode" "$md5" "$sha" "$notes"
}
