#!/usr/bin/env bash
# Detect long leading/trailing silence and optional clipping.

convert_one() {
  local src="$1" report dur lead=0 trail=0 clipped=0 issues=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would silence-check: $src"; return 0
  fi

  dur=$(audio_duration_sec "$src") || dur=0
  report=$(ffmpeg -hide_banner -i "$src" -af \
    "silencedetect=noise=${SILENCE_DB}dB:d=${SILENCE_SEC},astats=metadata=1:reset=1" \
    -f null - 2>&1) || true

  # Leading silence: silence_start near 0
  if printf '%s\n' "$report" | awk -v lim="$SILENCE_SEC" '
    /silence_start:/ {
      t=$NF+0
      if (t <= 0.05) lead=1
    }
    /silence_end:/ {
      # trailing: silence that ends at EOF handled below
    }
    END { exit lead?0:1 }
  '; then
    lead=1
  fi

  # Trailing: last silence_start within SILENCE_SEC of duration
  if [[ -n "$dur" && "$dur" != 0 ]]; then
    if printf '%s\n' "$report" | awk -v dur="$dur" -v lim="$SILENCE_SEC" '
      /silence_start:/ { last=$NF+0 }
      END {
        if (last != "" && (dur - last) <= lim + 0.05) exit 0
        exit 1
      }
    '; then
      trail=1
    fi
  fi

  if [[ "${CLIP_FAIL:-1}" -eq 1 ]]; then
    # Peak at full scale
    if printf '%s\n' "$report" | grep -E 'Peak level dB:[[:space:]]*0\.0' >/dev/null 2>&1; then
      clipped=1
    fi
    # Also check Peak count from astats
    if printf '%s\n' "$report" | awk '/Peak count:/ { if ($NF+0 > 0) found=1 } END { exit found?0:1 }'; then
      clipped=1
    fi
  fi

  [[ "$lead" -eq 1 ]] && issues+=("leading-silence")
  [[ "$trail" -eq 1 ]] && issues+=("trailing-silence")
  [[ "$clipped" -eq 1 ]] && issues+=("clipping")

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$src" "silence/clip issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $src"
  log_success "$src" "clean" "" "$(file_sha256 "$src")" "ok"
}
