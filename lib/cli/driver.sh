#!/usr/bin/env bash
# Shared CLI driver for audio-utils converter tools.
#
# Call after sourcing the tool's lib/plugin.sh. Plugin must set:
#   AU_TOOL_NAME          e.g. flac-to-wav
#   AU_SOURCE_EXT         e.g. flac (primary; used in messages)
#   AU_SOURCE_EXTS        optional space-separated list (default: AU_SOURCE_EXT)
#   AU_DEST_EXT           e.g. wav
#   AU_DISK_FACTOR        e.g. 2 or 1.5 (default 3)
#   AU_SUCCESS_COLUMNS    CSV header hint for finalize tip
#   AU_QUEUE_EMPTY_DIRS   if 1, queue DIR itself when it has no matching files
#                         (dir-level utils such as empty-dirs)
#   AU_GETOPT_EXTRA       extra getopts chars (e.g. 'Q:cR')
#
# Plugin must define:
#   convert_one PATH
#   delete_one_existing PATH
#   init_success_log
#   plugin_require_deps          # return non-zero on failure
# Optional:
#   plugin_parse_opt OPT OPTARG  # handle AU_GETOPT_EXTRA opts; return 0 if handled
#   plugin_consume_arg "$@"      # long-opt: return 0 and set AU_CONSUMED=N if handled
#   plugin_after_flags           # validate/normalize after shared flag parsing
#   plugin_banner_extra          # extra log_always lines
#   plugin_export_env            # export tool-specific env for workers
#   plugin_accept_source PATH    # return 0 to queue; non-zero to skip
#   plugin_finalize OK FAIL      # after run summary / success-fail logs
#
# Entry: audio_utils_run "$@"

_AUDIO_UTILS_DRIVER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Prefer lib dir from load.sh if already sourced; else this file's directory.
: "${_AUDIO_UTILS_LIB_DIR:=$_AUDIO_UTILS_DRIVER_DIR}"

audio_utils_driver_usage() {
  local exit_code="${1:-0}"
  # Usage errors: short stderr hint only (avoid dumping full help into stdout).
  # Explicit -h/--help: full help on stdout.
  if [[ "$exit_code" -ne 0 ]]; then
    echo "Try '${AU_TOOL_NAME:-tool}.sh -h' for usage." >&2
    exit "$exit_code"
  fi
  if [[ -n "${AU_USAGE_FILE:-}" && -f "${AU_USAGE_FILE}" ]]; then
    local start="${AU_USAGE_START:-2}"
    local end="${AU_USAGE_END:-40}"
    sed -n "${start},${end}p" "$AU_USAGE_FILE" | sed 's/^# \?//'
  else
    cat <<EOF
Usage: ${AU_TOOL_NAME}.sh DIR [DIR ...]
       find-*-dirs.sh | ${AU_TOOL_NAME}.sh
Options: -f -d -D -L -S -n -y -j -q -v -h --version
EOF
  fi
  exit 0
}

audio_utils_finalize_run_logs() {
  local fail_lines success_lines fail_rows
  [[ "${DRY_RUN:-0}" -eq 0 ]] || return 0
  if [[ -n "${FAIL_LOG:-}" && -f "$FAIL_LOG" ]]; then
    fail_lines=$(wc -l <"$FAIL_LOG" | tr -d ' ')
    case "$FAIL_LOG" in
      *.jsonl)
        if [[ "${fail_lines:-0}" -eq 0 ]]; then rm -f -- "$FAIL_LOG"
        else log_always "Failures logged to: $FAIL_LOG ($fail_lines events)"; fi
        ;;
      *)
        if [[ "${fail_lines:-0}" -le 1 ]]; then rm -f -- "$FAIL_LOG"
        else
          fail_rows=$((fail_lines - 1))
          log_always "Failures logged to: $FAIL_LOG ($fail_rows events)"
          log_always "  tip: column -t -s \$'\\t' \"$FAIL_LOG\" | less -S"
        fi
        ;;
    esac
  fi
  if [[ -n "${SUCCESS_LOG:-}" && -f "$SUCCESS_LOG" ]]; then
    success_lines=$(wc -l <"$SUCCESS_LOG" | tr -d ' ')
    case "$SUCCESS_LOG" in
      *.jsonl)
        if [[ "${success_lines:-0}" -eq 0 ]]; then rm -f -- "$SUCCESS_LOG"
        else log_always "Success log: $SUCCESS_LOG ($success_lines events)"; fi
        ;;
      *)
        if [[ "${success_lines:-0}" -le 1 ]]; then rm -f -- "$SUCCESS_LOG"
        else
          log_always "Success log: $SUCCESS_LOG ($((success_lines - 1)) rows)"
          [[ -n "${AU_SUCCESS_COLUMNS:-}" ]] && \
            log_always "  columns: ${AU_SUCCESS_COLUMNS}"
        fi
        ;;
    esac
  fi
}

audio_utils_run() {
  local DIR_FILE="" FAIL_LOG_DEFAULT=1 SUCCESS_LOG_DEFAULT=1
  local opt OPTARG OPTIND
  local -a DIRS=() ALL_SRCS=() args
  local -A DIR_CHECKED=()
  local dir srcs pre_fail=0 idx ok=0 fail=0 kept=0 elapsed local_i sf
  local getopt_spec free sibling

  : "${AU_TOOL_NAME:?AU_TOOL_NAME required}"
  : "${AU_SOURCE_EXT:?AU_SOURCE_EXT required}"
  : "${AU_DEST_EXT:?AU_DEST_EXT required}"
  : "${AU_TOOL_DIR:?AU_TOOL_DIR required}"

  AU_SOURCE_EXTS="${AU_SOURCE_EXTS:-$AU_SOURCE_EXT}"
  export AU_SOURCE_EXTS

  AUDIO_UTILS_WORKDIR_PREFIX="${AUDIO_UTILS_WORKDIR_PREFIX:-${AU_WORKDIR_PREFIX:-$AU_TOOL_NAME}}"
  export AUDIO_UTILS_WORKDIR_PREFIX
  CHECK_DISK_FACTOR="${AU_DISK_FACTOR:-3}"
  export CHECK_DISK_FACTOR

  DELETE_SOURCE=0
  DELETE_EXISTING=0
  DRY_RUN=0
  OVERWRITE=0
  QUIET=0
  VERBOSE=0
  JOBS=""
  FAIL_LOG="$(audio_utils_state_dir_path "$AU_TOOL_NAME")/failures.log"
  SUCCESS_LOG="$(audio_utils_state_dir_path "$AU_TOOL_NAME")/success.csv"
  DIRS=()

  # Long-option pre-pass (main shell — exit/--quality must not run in a subshell)
  args=()
  while (($# > 0)); do
    case "$1" in
      --version)
        audio_utils_print_version "$AU_TOOL_NAME"
        exit 0
        ;;
      --help)
        audio_utils_driver_usage 0
        ;;
      *)
        AU_CONSUMED=0
        if declare -F plugin_consume_arg >/dev/null 2>&1 && plugin_consume_arg "$@"; then
          if ! [[ "${AU_CONSUMED:-0}" =~ ^[1-9][0-9]*$ ]]; then
            echo "Error: plugin_consume_arg must set AU_CONSUMED >= 1" >&2
            exit 2
          fi
          shift "$AU_CONSUMED"
          continue
        fi
        if [[ "$1" == --* ]]; then
          echo "Error: unknown option: $1" >&2
          exit 2
        fi
        args+=("$1")
        shift
        ;;
    esac
  done
  set -- "${args[@]}"

  getopt_spec=":f:dDL:S:nj:qvyh${AU_GETOPT_EXTRA:-}"
  OPTIND=1
  while getopts "$getopt_spec" opt; do
    case "$opt" in
      f) DIR_FILE="$OPTARG" ;;
      d) DELETE_SOURCE=1 ;;
      D) DELETE_EXISTING=1 ;;
      L) FAIL_LOG="$OPTARG"; FAIL_LOG_DEFAULT=0 ;;
      S) SUCCESS_LOG="$OPTARG"; SUCCESS_LOG_DEFAULT=0 ;;
      n) DRY_RUN=1 ;;
      j) JOBS="$OPTARG" ;;
      q) QUIET=1 ;;
      v) VERBOSE=1 ;;
      y) OVERWRITE=1 ;;
      h) audio_utils_driver_usage 0 ;;
      \?)
        echo "Unknown option: -$OPTARG" >&2
        audio_utils_driver_usage 2
        ;;
      :)
        echo "Option -$OPTARG requires an argument" >&2
        audio_utils_driver_usage 2
        ;;
      *)
        if declare -F plugin_parse_opt >/dev/null 2>&1 && plugin_parse_opt "$opt" "${OPTARG:-}"; then
          :
        else
          echo "Unknown option: -$opt" >&2
          audio_utils_driver_usage 2
        fi
        ;;
    esac
  done
  shift $((OPTIND - 1))
  DIRS+=("$@")

  if [[ -n "$DIR_FILE" ]]; then
    [[ -f "$DIR_FILE" ]] || { echo "Error: file not found: $DIR_FILE" >&2; exit 2; }
    local -a file_dirs=()
    mapfile -t file_dirs < <(grep -v '^[[:space:]]*$' "$DIR_FILE" | grep -v '^#')
    DIRS+=("${file_dirs[@]}")
  fi

  if [[ ! -t 0 ]]; then
    local -a stdin_dirs=()
    mapfile -t stdin_dirs
    DIRS+=("${stdin_dirs[@]}")
  fi

  if ((${#DIRS[@]} == 0)); then
    echo "Error: no directories given." >&2
    audio_utils_driver_usage 2
  fi

  if [[ "$QUIET" -eq 1 && "$VERBOSE" -eq 1 ]]; then
    echo "Note: -q and -v both set; using verbose." >&2
    QUIET=0
  fi

  if [[ "$DELETE_EXISTING" -eq 1 ]]; then
    if [[ "$DELETE_SOURCE" -eq 1 || "$OVERWRITE" -eq 1 ]]; then
      echo "Note: -D is cleanup-only; -d/-y ignored." >&2
    fi
    DELETE_SOURCE=0
    OVERWRITE=0
  fi

  if declare -F plugin_after_flags >/dev/null 2>&1; then
    plugin_after_flags || exit 2
  fi

  if [[ -z "$JOBS" ]]; then
    JOBS=$(default_jobs)
  fi
  if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: -j must be a positive integer (got: $JOBS)" >&2
    exit 2
  fi

  if declare -F plugin_require_deps >/dev/null 2>&1; then
    plugin_require_deps || exit 2
  else
    require_cmds flac ffmpeg ffprobe flock || exit 2
  fi

  init_tmpdir_registry
  install_cleanup_trap

  local -a ENV_ROOTS=()
  audio_utils_roots_from_env ENV_ROOTS || true
  sweep_orphans_in_roots "${ENV_ROOTS[@]}" "${DIRS[@]}"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ "$FAIL_LOG_DEFAULT" -eq 1 ]]; then
      FAIL_LOG="$(audio_utils_state_dir "$AU_TOOL_NAME")/failures.log"
    fi
    if [[ "$SUCCESS_LOG_DEFAULT" -eq 1 ]]; then
      SUCCESS_LOG="$(audio_utils_state_dir "$AU_TOOL_NAME")/success.csv"
    fi
    init_fail_log || { echo "Error: cannot write failure log: $FAIL_LOG" >&2; exit 2; }
    init_success_log || exit 2
    log_always "=== $(audio_utils_print_version "$AU_TOOL_NAME" | tr -d '\n') ==="
    log_always "start:     $(au_iso_timestamp)"
    log_always "host:      $(hostname 2>/dev/null || echo unknown)"
    log_always "fail_log:  $FAIL_LOG"
    log_always "success:   $SUCCESS_LOG"
    log_always "jobs:      $JOBS"
    if declare -F plugin_banner_extra >/dev/null 2>&1; then
      plugin_banner_extra
    fi
  fi

  export DELETE_SOURCE DRY_RUN OVERWRITE DELETE_EXISTING
  export FAIL_LOG SUCCESS_LOG QUIET VERBOSE
  export AUDIO_UTILS_TMP_REGISTRY AUDIO_UTILS_WORKDIR_PREFIX CHECK_DISK_FACTOR
  export AU_TOOL_DIR AU_TOOL_NAME AU_SOURCE_EXT AU_SOURCE_EXTS AU_DEST_EXT
  # Back-compat aliases used by older convert modules during transition
  export DELETE_WAV="$DELETE_SOURCE" DELETE_FLAC="$DELETE_SOURCE"

  if declare -F plugin_export_env >/dev/null 2>&1; then
    plugin_export_env
  fi

  ALL_SRCS=()
  DIR_CHECKED=()
  pre_fail=0

  for dir in "${DIRS[@]}"; do
    dir="${dir#"${dir%%[![:space:]]*}"}"
    dir="${dir%"${dir##*[![:space:]]}"}"
    [[ -z "$dir" ]] && continue

    if [[ ! -d "$dir" ]]; then
      log_always "skip (not a dir): $dir"
      continue
    fi

    local -a find_expr=() _exts
    local _e _first=1
    # shellcheck disable=SC2206
    _exts=($AU_SOURCE_EXTS)
    for _e in "${_exts[@]}"; do
      if ((_first)); then
        find_expr=( -iname "*.${_e}" )
        _first=0
      else
        find_expr+=( -o -iname "*.${_e}" )
      fi
    done

    mapfile -t srcs < <(
      LC_ALL=C find -P "$dir" -maxdepth 1 -type f \( "${find_expr[@]}" \) | LC_ALL=C sort
    )

    if declare -F plugin_accept_source >/dev/null 2>&1; then
      local -a _accepted=()
      local _src
      for _src in "${srcs[@]}"; do
        if plugin_accept_source "$_src"; then
          _accepted+=("$_src")
        else
          log_info "skip (not accepted): $_src"
        fi
      done
      srcs=("${_accepted[@]}")
    fi

    if ((${#srcs[@]} == 0)); then
      # Dir-level utils (e.g. empty-dirs) may queue the directory itself when
      # AU_QUEUE_EMPTY_DIRS=1 and find listed empty dirs as scan targets.
      if [[ "${AU_QUEUE_EMPTY_DIRS:-0}" -eq 1 ]]; then
        log_info "==> $dir (dir candidate)"
        ALL_SRCS+=("$dir")
      else
        log_info "==> $dir"
        log_info "  (no matching .${AU_SOURCE_EXTS// /|} files)"
      fi
      continue
    fi

    if [[ "$DRY_RUN" -eq 0 && -z "${DIR_CHECKED[$dir]:-}" ]]; then
      sweep_orphan_workdirs "$dir"
      if ! check_disk_space "$dir" "${srcs[@]}"; then
        free=$(bytes_avail "$dir" 2>/dev/null || echo "?")
        for src in "${srcs[@]}"; do
          log_fail "$src" "insufficient disk space in $dir" \
            "need~${CHECK_DISK_FACTOR}x_largest free=$(human_bytes "${free:-0}")"
        done
        ((pre_fail += ${#srcs[@]})) || true
        DIR_CHECKED[$dir]=fail
        continue
      fi
      DIR_CHECKED[$dir]=ok
    fi

    log_info "==> $dir (${#srcs[@]} files)"
    ALL_SRCS+=("${srcs[@]}")
  done

  PROGRESS_TOTAL=${#ALL_SRCS[@]}
  PROGRESS_START=$(date +%s)
  export PROGRESS_TOTAL PROGRESS_START

  if ((PROGRESS_TOTAL == 0)); then
    if ((pre_fail > 0)); then
      log_always "Done. nothing converted; $pre_fail failed preflight."
      audio_utils_finalize_run_logs
      exit 1
    fi
    log_always "Done. nothing to do."
    audio_utils_finalize_run_logs
    exit 0
  fi

  log_info "Jobs: $JOBS  Total files: $PROGRESS_TOTAL"

  ok=0
  fail=0
  kept=0

  if [[ "$DELETE_EXISTING" -eq 1 ]]; then
    idx=0
    for src in "${ALL_SRCS[@]}"; do
      ((++idx))
      export PROGRESS_INDEX=$idx
      sibling="${src%.*}.${AU_DEST_EXT}"
      if [[ ! -f "$sibling" ]]; then
        log_progress "keep (no ${AU_DEST_EXT}): $src"
        ((kept++)) || true
        continue
      fi
      if delete_one_existing "$src"; then ((ok++)) || true
      else ((fail++)) || true; fi
    done
  elif ((JOBS > 1)); then
    STATUS_DIR=$(audio_utils_mktemp_d "status.XXXXXX")
    register_tmpdir "$STATUS_DIR"
    export STATUS_DIR
    # Serialize multi-line FAIL / progress lines across workers (screen readers,
    # log grepping). Single-line writes are still ordered per flock hold.
    AU_STDERR_LOCK="${STATUS_DIR}/.stderr.lock"
    : >"$AU_STDERR_LOCK"
    export AU_STDERR_LOCK
    idx=0
    args=()
    for src in "${ALL_SRCS[@]}"; do
      ((++idx))
      args+=("$idx" "$PROGRESS_TOTAL" "$PROGRESS_START" "$src")
    done
    while IFS= read -r _; do :; done < <(
      printf '%s\0' "${args[@]}" | xargs -0 -n 4 -P "$JOBS" \
        "${_AUDIO_UTILS_DRIVER_DIR}/worker.sh"
    )
    unset AU_STDERR_LOCK
    ok=0
    fail=0
    for ((local_i = 1; local_i <= PROGRESS_TOTAL; local_i++)); do
      sf="${STATUS_DIR}/${local_i}.status"
      if [[ -f "$sf" ]]; then
        case "$(<"$sf")" in
          OK) ((ok++)) || true ;;
          FAIL) ((fail++)) || true ;;
          *) ((fail++)) || true; log_err "warning: bad status in $sf" ;;
        esac
      else
        ((fail++)) || true
        log_err "warning: missing status for job $local_i/${PROGRESS_TOTAL}"
      fi
    done
    unregister_tmpdir "$STATUS_DIR"
    rm -rf -- "$STATUS_DIR"
  else
    idx=0
    for src in "${ALL_SRCS[@]}"; do
      ((++idx))
      export PROGRESS_INDEX=$idx
      if convert_one "$src"; then ((ok++)) || true
      else ((fail++)) || true; fi
    done
  fi

  ((fail += pre_fail)) || true
  elapsed=$(( $(date +%s) - PROGRESS_START ))
  log_always ""
  if [[ "$DELETE_EXISTING" -eq 1 ]]; then
    log_always "Done. deleted/ok=$ok kept_no_${AU_DEST_EXT}=$kept failed=$fail elapsed=$(fmt_dur "$elapsed")"
  else
    log_always "Done. ok=$ok failed=$fail elapsed=$(fmt_dur "$elapsed")"
  fi
  audio_utils_finalize_run_logs
  if declare -F plugin_finalize >/dev/null 2>&1; then
    plugin_finalize "$ok" "$fail" || true
  fi
  [[ "$fail" -eq 0 ]]
}
