#!/usr/bin/env bash
# Bounded-concurrency job pool for local check/test runs.
#
# Uses background jobs + `wait -n` (bash 4.3+). Prefer this over `coproc` for
# fan-out work: coproc is for long-lived bidirectional helpers; a wait -n pool
# caps concurrency for many short tasks and aggregates exit status.
#
# Usage (CLI):
#   run_parallel.sh [-j N] DIR [DIR ...]
#     → make -C DIR check  for each DIR
#
# Usage (sourced):
#   source lib/run_parallel.sh
#   run_parallel JOBS callback arg [arg ...]
#     → callback is invoked as: callback "$arg"  (each in a subshell)
#
# Env:
#   RUN_PARALLEL_JOBS / JOBS  default concurrency when -j unset

set -u

_run_parallel_default_jobs() {
  local n
  n=${RUN_PARALLEL_JOBS:-${JOBS:-}}
  if [[ -n "$n" && "$n" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' "$n"
    return
  fi
  n=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
  printf '%s\n' "$n"
}

_run_parallel_have_wait_n() {
  ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3)))
}

# Reap one finished job; set fail=1 on non-zero status.
# shellcheck disable=SC2034  # fail is nameref'd from caller
_run_parallel_reap() {
  local -n _fail=$1
  if _run_parallel_have_wait_n; then
    if ! wait -n; then
      _fail=1
    fi
  else
    # Pre-4.3: wait for all outstanding jobs (still launched in parallel).
    if ! wait; then
      _fail=1
    fi
  fi
}

# run_parallel JOBS CALLBACK ARG [ARG ...]
run_parallel() {
  local max_jobs=$1
  local callback=$2
  shift 2

  if ! [[ "$max_jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "run_parallel: JOBS must be a positive integer (got: $max_jobs)" >&2
    return 2
  fi
  if ! declare -F "$callback" >/dev/null 2>&1; then
    echo "run_parallel: callback is not a function: $callback" >&2
    return 2
  fi
  if (($# == 0)); then
    return 0
  fi

  # No wait -n: fall back to xargs -P (same semantics as before).
  if ! _run_parallel_have_wait_n; then
    local item
    local -a args=()
    for item in "$@"; do
      args+=("$item")
    done
    # Export callback body via a temp wrapper so xargs can invoke it.
    local wrap
    wrap=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f -- '$wrap'" RETURN
    {
      echo '#!/usr/bin/env bash'
      declare -f "$callback"
      echo "$callback \"\$1\""
    } >"$wrap"
    chmod +x "$wrap"
    set -o pipefail
    printf '%s\0' "${args[@]}" | xargs -0 -n 1 -P "$max_jobs" "$wrap"
    return $?
  fi

  local running=0 fail=0 item

  for item in "$@"; do
    while ((running >= max_jobs)); do
      _run_parallel_reap fail
      ((running--)) || true
    done
    (
      "$callback" "$item"
    ) &
    ((++running))
  done

  while ((running > 0)); do
    _run_parallel_reap fail
    ((running--)) || true
  done

  return "$fail"
}

# CLI: make -C DIR check for each directory argument.
_run_parallel_make_check() {
  local dir=$1
  make -C "$dir" check
}

_run_parallel_cli() {
  local jobs=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -j)
        [[ $# -ge 2 ]] || {
          echo "run_parallel.sh: -j needs a value" >&2
          return 2
        }
        jobs=$2
        shift 2
        ;;
      -j*)
        jobs=${1#-j}
        shift
        ;;
      -h | --help)
        cat >&2 <<'EOF'
Usage: run_parallel.sh [-j N] DIR [DIR ...]

Run `make -C DIR check` for each DIR with at most N concurrent jobs
(default: nproc / RUN_PARALLEL_JOBS / JOBS).

Uses a bash job pool (background tasks + wait -n), not coproc.
EOF
        return 2
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "run_parallel.sh: unknown option: $1" >&2
        return 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ -z "$jobs" ]]; then
    jobs=$(_run_parallel_default_jobs)
  fi
  if (($# == 0)); then
    return 0
  fi

  run_parallel "$jobs" _run_parallel_make_check "$@"
}

# Only run CLI when executed; allow `source lib/run_parallel.sh` for run_parallel().
if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  set -eo pipefail
  _run_parallel_cli "$@"
fi
