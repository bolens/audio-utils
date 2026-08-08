#!/usr/bin/env bash
# Unit-level CLI contract tests for custom disc parsers.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_CDDA="$AU_REPO_ROOT/conversion/cdda-to-flac/cdda-to-flac.sh"

test_cdda_missing_option_values_exit_two() {
  local flag
  for flag in -o -d -L -S -j; do
    assert_exit 2 "$_CDDA" "$flag" 2>/dev/null
  done
}

test_cdda_rejects_invalid_jobs_before_dependency_checks() {
  local jobs
  for jobs in 0 -1 nope 1.5; do
    local out rc=0
    out=$("$_CDDA" -j "$jobs" 2>&1) || rc=$?
    assert_eq "$rc" "2"
    assert_grep "positive integer" "$out"
  done
}

test_cdda_rejects_multiple_positional_devices() {
  local out rc=0
  out=$("$_CDDA" /dev/cdrom /dev/sr1 2>&1) || rc=$?
  assert_eq "$rc" "2"
  assert_grep "only one CD device" "$out"
}

test_cdda_accepts_positive_jobs_during_help() {
  assert_exit 0 "$_CDDA" -j 1 --help 2>/dev/null
}

run_tests
