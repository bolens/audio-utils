#!/usr/bin/env bash
log_success() {
  local flac="$1" m4a="$2" md5="$3" sha="$4" notes="${5:-}"
  local codec bytes samples ts
  [[ "${DRY_RUN:-0}" -eq 1 || -z "${SUCCESS_LOG:-}" ]] && return 0
  IFS=$'\t' read -r codec bytes samples < <(probe_debug_fields "$flac")
  ts=$(date -Iseconds)
  case "${SUCCESS_LOG}" in
    *.jsonl)
      append_locked "${SUCCESS_LOG}" \
        '{"ts":"%s","flac":%s,"m4a":%s,"audio_md5":"%s","m4a_sha256":"%s","codec":%s,"bytes":%s,"samples":%s,"notes":%s}\n' \
        "$ts" "$(json_str "$flac")" "$(json_str "$m4a")" "$md5" "$sha" \
        "$(json_str "${codec:-}")" "${bytes:-0}" "$(json_str "${samples:-}")" "$(json_str "$notes")"
      ;;
    *)
      append_locked "${SUCCESS_LOG}" '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$ts" "$(csv_escape "$flac")" "$(csv_escape "$m4a")" "$md5" "$sha" \
        "$(csv_escape "${codec:-}")" "${bytes:-0}" "$(csv_escape "${samples:-}")" "$(csv_escape "$notes")"
      ;;
  esac
}
init_success_log() {
  [[ "${DRY_RUN:-0}" -eq 1 || -z "${SUCCESS_LOG:-}" ]] && return 0
  audio_utils_ensure_log_file "$SUCCESS_LOG" truncate || { log_err "cannot write success log"; return 1; }
  case "${SUCCESS_LOG}" in
    *.jsonl) ;;
    *) printf '%s\n' 'timestamp,flac,m4a,audio_md5,m4a_sha256,codec,bytes,samples,notes' >"${SUCCESS_LOG}"
       chmod 600 -- "${SUCCESS_LOG}" 2>/dev/null || true ;;
  esac
  log_info "Success log: ${SUCCESS_LOG}"
}
