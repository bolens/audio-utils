#!/usr/bin/env bash
# Unit tests: tests/run.sh filtering and empty-match semantics.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_write_runner_fixture() {
  local file=$1
  cat >"$file" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$AU_REPO_ROOT/tests/harness.sh"
test_alpha() { :; }
test_beta() { :; }
run_tests
EOF
}

test_function_filter_runs_only_matching_test() {
  _write_runner_fixture "$T/sample.test.sh"
  local rc=0
  "$AU_REPO_ROOT/tests/run.sh" -j 1 -k alpha "$T/sample.test.sh" \
    >"$T/out" 2>&1 || rc=$?
  assert_eq "$rc" 0
  assert_grep 'pass=1 fail=0 skip=0' "$T/out"
  assert_not_grep 'ok test_beta' "$T/out"
}

test_missing_function_filter_returns_usage_error() {
  _write_runner_fixture "$T/sample.test.sh"
  local rc=0
  "$AU_REPO_ROOT/tests/run.sh" -j 1 -k does_not_exist "$T/sample.test.sh" \
    >"$T/out" 2>&1 || rc=$?
  assert_eq "$rc" 2
  assert_grep 'pass=0 fail=0 skip=0' "$T/out"
  assert_grep 'NO MATCHING TEST FUNCTIONS' "$T/out"
}

test_filename_filter_keeps_all_functions_in_matching_file() {
  _write_runner_fixture "$T/sample.test.sh"
  local rc=0
  "$AU_REPO_ROOT/tests/run.sh" -j 1 -k sample "$T/sample.test.sh" \
    >"$T/out" 2>&1 || rc=$?
  assert_eq "$rc" 0
  assert_grep 'pass=2 fail=0 skip=0' "$T/out"
}


_write_xdg_fixture() {
  cat >"$1" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$AU_REPO_ROOT/tests/harness.sh"
test_xdg_data() {
  [[ "$XDG_DATA_HOME" == "$AU_TEST_SANDBOX/data" ]] || return 1
  [[ -d "$XDG_DATA_HOME" ]] || return 1
  printf 'fixture\n' >"$XDG_DATA_HOME/probe"
}
run_tests
EOF
}

test_runner_isolates_inherited_xdg_data_home() {
  _write_xdg_fixture "$T/xdg.test.sh"
  mkdir "$T/caller-data"
  local rc=0
  env -u AU_TEST_FILTER XDG_DATA_HOME="$T/caller-data" "$AU_REPO_ROOT/tests/run.sh" -j 1 "$T/xdg.test.sh" \
    >"$T/out" 2>&1 || rc=$?
  assert_eq "$rc" 0 || return
  assert_grep 'pass=1 fail=0 skip=0' "$T/out" || return
  [[ ! -e "$T/caller-data/probe" ]]
}

test_direct_harness_isolates_inherited_xdg_data_home() {
  _write_xdg_fixture "$T/xdg.test.sh"
  mkdir "$T/caller-data"
  local rc=0
  env -u AU_TEST_SANDBOX -u AU_TEST_FILTER XDG_DATA_HOME="$T/caller-data" bash "$T/xdg.test.sh" \
    >"$T/out" 2>&1 || rc=$?
  assert_eq "$rc" 0 || return
  assert_grep 'pass=1 fail=0 skip=0' "$T/out" || return
  [[ ! -e "$T/caller-data/probe" ]]
}

run_tests
