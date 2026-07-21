#!/usr/bin/env bash
# Dedupe one playlist in place (keep first occurrence).

convert_one() {
  local pl="$1"
  local basedir fmt entries_file deduped dropped=0 total before after counts

  basedir=$(cd -- "$(dirname -- "$pl")" && pwd) || {
    log_fail "$pl" "cannot resolve directory"
    return 1
  }

  if ! fmt=$(playlist_detect_format "$pl"); then
    log_fail "$pl" "unknown playlist format"
    return 1
  fi
  case "$fmt" in
    m3u) ;;
    *) ;;
  esac

  entries_file=$(audio_utils_mktemp "plentries.XXXXXX") || return 1
  playlist_parse "$pl" >"$entries_file" || {
    log_fail "$pl" "parse failed"
    return 1
  }
  before=$(wc -l <"$entries_file" | tr -d ' ')

  counts=$(playlist_count_dupes "${PLAYLIST_DEDUPE_BY:-path}" <"$entries_file")
  dropped=${counts##* }
  total=${counts%% *}

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if ((dropped == 0)); then
      log_progress "would skip (no dupes): $pl ($total entries)"
    else
      log_progress "would dedupe: $pl (drop $dropped of $total)"
    fi
    return 0
  fi

  if ((dropped == 0)); then
    log_progress "skip (no dupes): $pl"
    log_success "$pl" "skip" "" "$(file_sha256 "$pl")" "no-dupes"
    return 0
  fi

  if [[ "${OVERWRITE:-0}" -eq 0 ]]; then
    log_fail "$pl" "dupes found; pass -y to rewrite" "would_drop=${dropped}"
    return 1
  fi

  deduped=$(audio_utils_mktemp "pldeduped.XXXXXX") || return 1
  PLAYLIST_DEDUPE_COUNT_FILE=$(audio_utils_mktemp "pldcount.XXXXXX")
  export PLAYLIST_DEDUPE_COUNT_FILE
  playlist_dedupe_entries "${PLAYLIST_DEDUPE_BY:-path}" <"$entries_file" >"$deduped"
  dropped=$(cat "$PLAYLIST_DEDUPE_COUNT_FILE" 2>/dev/null || echo "$dropped")
  unset PLAYLIST_DEDUPE_COUNT_FILE
  after=$(wc -l <"$deduped" | tr -d ' ')

  if ! playlist_write "$fmt" "$pl" "$basedir" relative <"$deduped"; then
    log_fail "$pl" "write failed"
    return 1
  fi

  log_progress "deduped: $pl ($before → $after, dropped $dropped)"
  log_success "$pl" "deduped" "" "$(file_sha256 "$pl")" "dropped=${dropped}"
}
