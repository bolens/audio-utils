#!/usr/bin/env bash
# dynamics-report — EBU R128 loudness / dynamics survey.

AU_TOOL_NAME="${AU_TOOL_NAME:-dynamics-report}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc spx aac wav aiff aif"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=dynrep
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

DYN_MIN_LRA="${DYN_MIN_LRA:-3}"

plugin_consume_arg() {
  case "${1:-}" in
    --min-lra=*)
      DYN_MIN_LRA="${1#--min-lra=}"; AU_CONSUMED=1
      export AU_CONSUMED DYN_MIN_LRA; return 0 ;;
    --min-lra)
      [[ -n "${2:-}" ]] || { echo "Error: --min-lra needs N" >&2; return 1; }
      DYN_MIN_LRA=$2; AU_CONSUMED=2
      export AU_CONSUMED DYN_MIN_LRA; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: dynamics-report is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: dynamics-report is read-only; -y is not supported" >&2
    return 1
  fi
  if ! [[ "$DYN_MIN_LRA" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: --min-lra must be a number (got: $DYN_MIN_LRA)" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock awk
}

plugin_banner_extra() {
  log_always "mode:      EBU R128 survey (I / LRA / true peak; min-lra=${DYN_MIN_LRA})"
}

plugin_export_env() {
  if [[ -z "${AU_DYN_STATE:-}" ]]; then
    AU_DYN_STATE=$(audio_utils_mktemp_d "dynrep.XXXXXX")
    register_tmpdir "$AU_DYN_STATE"
  fi
  AU_DYN_REPORT="${AU_DYN_REPORT:-$(audio_utils_state_dir_path "$AU_TOOL_NAME")/dynamics-report.txt}"
  export AU_DYN_STATE AU_DYN_REPORT DYN_MIN_LRA AU_CLEANUP_SKIP AU_SOURCE_EXTS
}

plugin_finalize() {
  local rows="${AU_DYN_STATE:-}/rows.tsv"
  local report="${AU_DYN_REPORT:-}"
  local n
  [[ -f "$rows" ]] || {
    log_always "Dynamics: no rows collected"
    return 0
  }
  n=$(wc -l <"$rows" | tr -d ' ')
  mkdir -p -- "$(dirname -- "$report")" 2>/dev/null || true
  {
    echo "dynamics-report (EBU R128)"
    echo "files: $n"
    echo
    echo "=== integrated loudness (LUFS) ==="
    awk -F'\t' '
      $2 != "?" { sum += $2; c++; if (c == 1 || $2 < min) min = $2; if (c == 1 || $2 > max) max = $2 }
      END {
        if (c > 0) printf "  mean: %.1f  min: %.1f  max: %.1f  (n=%d)\n", sum / c, min, max, c
        else print "  (none measured)"
      }
    ' "$rows"
    echo
    echo "=== loudness range (LU) ==="
    awk -F'\t' '
      $3 != "?" { sum += $3; c++; if (c == 1 || $3 < min) min = $3; if (c == 1 || $3 > max) max = $3 }
      END {
        if (c > 0) printf "  mean: %.1f  min: %.1f  max: %.1f  (n=%d)\n", sum / c, min, max, c
        else print "  (none measured)"
      }
    ' "$rows"
    echo
    echo "=== low-LRA files (LRA < ${DYN_MIN_LRA} LU; brickwall suspects) ==="
    awk -F'\t' -v lim="$DYN_MIN_LRA" \
      '$3 != "?" && $3 + 0 < lim + 0 { printf "  LRA=%s I=%s peak=%s  %s\n", $3, $2, $4, $1 }' \
      "$rows" | LC_ALL=C sort -t= -k2 -n
    echo
    echo "=== true peak over 0 dBFS ==="
    awk -F'\t' '$4 != "?" && $4 + 0 > 0 { printf "  peak=%s  %s\n", $4, $1 }' "$rows"
  } >"$report"
  chmod 600 -- "$report" 2>/dev/null || true
  log_always "Dynamics report: $report"
  cat -- "$report"
}
