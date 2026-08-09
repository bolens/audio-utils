#!/usr/bin/env bash
# Unit-level contract tests for scripts/coverage-audit.sh.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_AUDIT="$AU_REPO_ROOT/scripts/coverage-audit.sh"

test_exempt_tool_mentions_do_not_claim_full_coverage() {
  local out
  out=$(bash "$_AUDIT")
  assert_not_grep "WARNING: exempt entries" "$out"
  assert_grep "conversion/bluray-to-flac" "$out"
  assert_grep "conversion/dvd-to-flac" "$out"
}

test_coverage_lists_are_machine_readable() {
  local out
  out=$(bash "$_AUDIT" --list exempt)
  assert_grep '^conversion/cdda-to-flac$' "$out"
  assert_not_grep 'Coverage:' "$out"
}

test_bad_coverage_arguments_exit_two() {
  assert_exit 2 bash "$_AUDIT" --goal nope 2>/dev/null
  assert_exit 2 bash "$_AUDIT" --list unknown 2>/dev/null
}

run_tests
