#!/usr/bin/env bash
# Fingerprint one file, query AcoustID, compare against the embedded MBID.

_tl_uuid_re='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# Extract MusicBrainz recording ids from an AcoustID JSON response.
_tl_recording_ids() {
  local resp=$1
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$resp" \
      | jq -r '.results[]?.recordings[]?.id // empty' 2>/dev/null \
      | LC_ALL=C sort -u
  else
    # Coarse fallback: every UUID-valued "id" field (includes AcoustID track
    # ids, so membership tests stay valid but candidates are noisier).
    printf '%s' "$resp" \
      | grep -Eo '"id"[[:space:]]*:[[:space:]]*"'"$_tl_uuid_re"'"' \
      | grep -Eo "$_tl_uuid_re" \
      | LC_ALL=C sort -u
  fi
}

_tl_embedded_mbid() {
  local f=$1 v
  v=$(audio_meta_get "$f" MUSICBRAINZ_TRACKID)
  [[ -n "$v" ]] || v=$(audio_meta_get "$f" "MusicBrainz Track Id")
  printf '%s' "${v,,}"
}

convert_one() {
  local f="$1" out dur fp resp embedded candidate
  local -a ids=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would acoustid-lookup: $f"; return 0
  fi

  out=$(fpcalc -- "$f" 2>/dev/null) || {
    log_fail "$f" "fpcalc fingerprint failed"
    return 1
  }
  dur=$(sed -n 's/^DURATION=//p' <<<"$out" | head -n1)
  fp=$(sed -n 's/^FINGERPRINT=//p' <<<"$out" | head -n1)
  if [[ -z "$dur" || -z "$fp" ]]; then
    log_fail "$f" "fpcalc produced no fingerprint"
    return 1
  fi

  sleep "${LOOKUP_DELAY:-0.4}"
  # ACOUSTID_API_URL override exists for tests (local mock server).
  resp=$(curl -fsS --max-time 30 --get \
    "${ACOUSTID_API_URL:-https://api.acoustid.org/v2/lookup}" \
    --data-urlencode "client=${ACOUSTID_CLIENT_KEY:?}" \
    --data-urlencode "duration=${dur}" \
    --data-urlencode "meta=recordingids" \
    --data-urlencode "fingerprint=${fp}") || {
    log_fail "$f" "acoustid request failed" "network/curl"
    return 1
  }
  if ! grep -Eq '"status"[[:space:]]*:[[:space:]]*"ok"' <<<"$resp"; then
    log_fail "$f" "acoustid error response" "$(head -c 200 <<<"$resp")"
    return 1
  fi

  mapfile -t ids < <(_tl_recording_ids "$resp")
  embedded=$(_tl_embedded_mbid "$f")

  if ((${#ids[@]} == 0)); then
    log_fail "$f" "no acoustid match" "embedded=${embedded:-none}"
    return 1
  fi

  candidate=${ids[0]}
  if [[ -z "$embedded" ]]; then
    log_fail "$f" "missing MUSICBRAINZ_TRACKID" "candidate=${candidate};matches=${#ids[@]}"
    return 1
  fi

  local id
  for id in "${ids[@]}"; do
    if [[ "${id,,}" == "$embedded" ]]; then
      log_progress "ok: $f (mbid matches)"
      log_success "$f" "match" "" "" "mbid=${embedded}"
      return 0
    fi
  done

  log_fail "$f" "embedded MBID not in acoustid results" \
    "embedded=${embedded};candidate=${candidate};matches=${#ids[@]}"
  return 1
}
