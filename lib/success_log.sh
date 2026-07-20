#!/usr/bin/env bash
# Generic success log (CSV / JSONL) driven by AU_SUCCESS_COLUMNS.
#
# Column order (fixed semantics):
#   timestamp, <src>, <dest>, <*md5*>, <*sha*>, codec, bytes, samples, [quality], notes
#
# Usage:
#   log_success SRC DEST MD5 SHA NOTES
#   log_success SRC DEST MD5 SHA QUALITY NOTES   # when columns include quality
#
# Quality (when column present) also falls back to:
#   AU_SUCCESS_QUALITY → LOSSY_QUALITY_NAME → MP3_QUALITY_NAME

init_success_log() {
  [[ "${DRY_RUN:-0}" -eq 1 || -z "${SUCCESS_LOG:-}" ]] && return 0
  [[ -n "${AU_SUCCESS_COLUMNS:-}" ]] || {
    log_err "Error: AU_SUCCESS_COLUMNS is required for success logging"
    return 1
  }
  audio_utils_ensure_log_file "$SUCCESS_LOG" truncate || {
    log_err "Error: cannot write success log: $SUCCESS_LOG"
    return 1
  }
  case "${SUCCESS_LOG}" in
    *.jsonl) ;;
    *)
      printf '%s\n' "${AU_SUCCESS_COLUMNS}" >"${SUCCESS_LOG}"
      chmod 600 -- "${SUCCESS_LOG}" 2>/dev/null || true
      ;;
  esac
  log_info "Success log: ${SUCCESS_LOG}"
}

# Resolve field values for AU_SUCCESS_COLUMNS into parallel arrays _sl_keys / _sl_vals.
_success_log_fields() {
  local src="$1" dest="$2" md5="$3" sha="$4" notes="$5" quality="${6:-}"
  local codec bytes samples ts col val
  local src_done=0
  local IFS=,

  IFS=$'\t' read -r codec bytes samples < <(probe_debug_fields "$src")
  ts=$(au_iso_timestamp)

  _sl_keys=()
  _sl_vals=()
  # shellcheck disable=SC2206
  local -a cols=(${AU_SUCCESS_COLUMNS})
  for col in "${cols[@]}"; do
    case "$col" in
      timestamp) val=$ts ;;
      codec) val=${codec:-} ;;
      bytes) val=${bytes:-0} ;;
      samples) val=${samples:-} ;;
      notes) val=$notes ;;
      quality)
        val=${quality:-${AU_SUCCESS_QUALITY:-${LOSSY_QUALITY_NAME:-${MP3_QUALITY_NAME:-}}}}
        ;;
      *md5*) val=$md5 ;;
      *sha256*|*sha*) val=$sha ;;
      *)
        if [[ "$src_done" -eq 0 ]]; then
          val=$src
          src_done=1
        else
          val=$dest
        fi
        ;;
    esac
    _sl_keys+=("$col")
    _sl_vals+=("$val")
  done
}

log_success() {
  local src="$1" dest="$2" md5="$3" sha="$4"
  local notes="" quality=""
  local i n fmt json_fmt
  local -a csv_args json_args

  [[ "${DRY_RUN:-0}" -eq 1 || -z "${SUCCESS_LOG:-}" ]] && return 0
  [[ -n "${AU_SUCCESS_COLUMNS:-}" ]] || return 0

  if [[ "${AU_SUCCESS_COLUMNS}" == *quality* ]]; then
    if (($# >= 6)); then
      quality=$5
      notes=$6
    else
      notes=${5:-}
    fi
  else
    notes=${5:-}
  fi

  _success_log_fields "$src" "$dest" "$md5" "$sha" "$notes" "$quality"
  n=${#_sl_keys[@]}

  case "${SUCCESS_LOG}" in
    *.jsonl)
      json_fmt='{'
      json_args=()
      for ((i = 0; i < n; i++)); do
        if ((i > 0)); then
          json_fmt+=','
        fi
        case "${_sl_keys[$i]}" in
          bytes)
            json_fmt+="\"${_sl_keys[$i]}\":%s"
            json_args+=("${_sl_vals[$i]}")
            ;;
          ts|timestamp)
            # Prefer short key "ts" in JSON for timestamp column.
            if [[ "${_sl_keys[$i]}" == timestamp ]]; then
              json_fmt+='"ts":"%s"'
            else
              json_fmt+="\"${_sl_keys[$i]}\":\"%s\""
            fi
            json_args+=("${_sl_vals[$i]}")
            ;;
          *md5*|*sha256*|*sha*)
            json_fmt+="\"${_sl_keys[$i]}\":\"%s\""
            json_args+=("${_sl_vals[$i]}")
            ;;
          *)
            json_fmt+="\"${_sl_keys[$i]}\":%s"
            json_args+=("$(json_str "${_sl_vals[$i]}")")
            ;;
        esac
      done
      json_fmt+='}\n'
      # shellcheck disable=SC2059
      append_locked "${SUCCESS_LOG}" "$json_fmt" "${json_args[@]}"
      ;;
    *)
      fmt=""
      csv_args=()
      for ((i = 0; i < n; i++)); do
        if ((i > 0)); then
          fmt+=','
        fi
        case "${_sl_keys[$i]}" in
          bytes|timestamp|*md5*|*sha256*|*sha*)
            fmt+='%s'
            csv_args+=("${_sl_vals[$i]}")
            ;;
          *)
            fmt+='%s'
            csv_args+=("$(csv_escape "${_sl_vals[$i]}")")
            ;;
        esac
      done
      fmt+='\n'
      # shellcheck disable=SC2059
      append_locked "${SUCCESS_LOG}" "$fmt" "${csv_args[@]}"
      ;;
  esac
}
