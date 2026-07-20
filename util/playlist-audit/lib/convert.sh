#!/usr/bin/env bash
# Audit one playlist: parse, missing paths, empty, duplicates, UTF-8.

convert_one() {
  local pl="$1"
  local -a issues=() entries=()
  local total=0 missing=0 dupes=0 path counts line

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would audit-playlist: $pl"
    return 0
  fi

  if command -v iconv >/dev/null 2>&1; then
    if ! iconv -f UTF-8 -t UTF-8 -- "$pl" >/dev/null 2>&1; then
      issues+=("non-utf8")
    fi
  fi

  if ! playlist_detect_format "$pl" >/dev/null 2>&1; then
    issues+=("unknown-format")
    local IFS=';'
    log_fail "$pl" "playlist audit issues" "${issues[*]}"
    return 1
  fi

  mapfile -t entries < <(playlist_parse "$pl" 2>/dev/null || true)
  total=${#entries[@]}
  if ((total == 0)); then
    issues+=("empty")
  fi

  for line in "${entries[@]}"; do
    IFS=$'\x1f' read -r path _ _ <<<"$line"
    [[ -n "$path" ]] || continue
    if [[ ! -e "$path" || ! -r "$path" ]]; then
      ((missing++)) || true
    fi
  done
  if ((missing > 0)); then
    issues+=("missing=${missing}")
  fi

  if ((total > 0)); then
    counts=$(printf '%s\n' "${entries[@]}" | playlist_count_dupes "${PLAYLIST_DEDUPE_BY:-path}")
    dupes=${counts##* }
    if ((dupes > 0)); then
      issues+=("dupes=${dupes}")
    fi
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$pl" "playlist audit issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $pl ($total entries)"
  log_success "$pl" "clean" "" "$(file_sha256 "$pl")" "entries=$total"
}
