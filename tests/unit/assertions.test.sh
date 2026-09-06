#!/usr/bin/env bash
# Regression coverage for grep assertions under pipefail and large input.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_large_assertion_input() {
  local padding
  printf -v padding '%*s' 1048576 ''
  printf 'needle\n%s\n' "$padding"
}

test_large_string_match_does_not_fail_on_writer_sigpipe() {
  local text
  text=$(_large_assertion_input)
  assert_grep '^needle$' "$text"
}

test_large_string_match_is_rejected_by_negative_assertion() {
  local text
  text=$(_large_assertion_input)
  if assert_not_grep '^needle$' "$text" >"$T/negative.out" 2>&1; then
    fail 'negative assertion accepted a present pattern'
  fi
}

test_missing_string_pattern_preserves_both_assertion_outcomes() {
  if assert_grep 'missing' 'present' >"$T/positive.out" 2>&1; then
    fail 'positive assertion accepted an absent pattern'
    return 1
  fi
  assert_not_grep 'missing' 'present'
}

run_tests
