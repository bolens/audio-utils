#!/usr/bin/env bash
# Unit tests: lib/cli/run_parallel.sh job pool.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/cli/run_parallel.sh"
}

test_runs_every_item_exactly_once() {
  require_cmd flock
  _load
  _cb() { flock "$T/lock" bash -c "echo '$1' >>'$T/seen'"; }
  run_parallel 3 _cb a b c d e || fail "pool failed on success case"
  assert_eq "$(sort "$T/seen" | tr '\n' ' ')" "a b c d e " "all items ran"
  assert_eq "$(wc -l <"$T/seen")" 5 "no duplicates"
}

test_failure_propagates_but_all_items_run() {
  require_cmd flock
  _load
  _cb() {
    flock "$T/lock" bash -c "echo '$1' >>'$T/seen'"
    [[ "$1" != fail-me ]]
  }
  local rc=0
  run_parallel 2 _cb ok1 fail-me ok2 ok3 || rc=$?
  assert_eq "$rc" 1 "failure must propagate"
  assert_eq "$(wc -l <"$T/seen")" 4 "remaining items still ran"
}

test_respects_concurrency_cap() {
  require_cmd flock
  _load
  # Track concurrent workers via a lock-protected counter; record the max.
  _cb() {
    (
      flock 9
      local cur max
      cur=$(cat "$T/cur" 2>/dev/null || echo 0)
      max=$(cat "$T/max" 2>/dev/null || echo 0)
      cur=$((cur + 1))
      echo "$cur" >"$T/cur"
      ((cur > max)) && echo "$cur" >"$T/max"
    ) 9>"$T/lock"
    sleep 0.15
    (
      flock 9
      echo $(($(cat "$T/cur") - 1)) >"$T/cur"
    ) 9>"$T/lock"
  }
  run_parallel 2 _cb 1 2 3 4 5 6 || fail "pool failed"
  local max
  max=$(cat "$T/max" 2>/dev/null || echo 0)
  ((max >= 1 && max <= 2)) || fail "concurrency cap violated: max=$max"
}

test_invalid_jobs_and_callback_return_two() {
  _load
  _cb() { :; }
  assert_exit 2 run_parallel 0 _cb a
  assert_exit 2 run_parallel abc _cb a
  assert_exit 2 run_parallel 2 no_such_function a
}

test_zero_items_is_noop_success() {
  _load
  _cb() { fail "callback must not run"; }
  run_parallel 4 _cb || fail "empty arg list must succeed"
}

run_tests
