#!/usr/bin/env bash
# Unit tests: immutable GitHub Action reference enforcement.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_write_workflow() {
  mkdir -p "$T/repo/.github/workflows"
  printf '%s\n' "$1" >"$T/repo/.github/workflows/test.yml"
}

_check_pins() {
  AUDIO_UTILS_ACTION_PINS_ROOT="$T/repo" \
    bash "$AU_REPO_ROOT/scripts/check-action-pins.sh"
}

test_accepts_full_sha_and_local_actions() {
  _write_workflow 'steps:
  - uses: actions/checkout@0123456789abcdef0123456789abcdef01234567 # v7
  - uses: ./.github/actions/local
  - uses: docker://alpine@sha256:0123456789abcdef'
  _check_pins || fail "valid immutable action references rejected"
}

test_rejects_mutable_tag() {
  _write_workflow 'steps:
  - uses: actions/checkout@v7'
  local rc=0 out
  out=$(_check_pins 2>&1) || rc=$?
  assert_eq "$rc" 1
  assert_grep "not pinned to a full commit SHA" "$out"
}

test_rejects_short_sha() {
  _write_workflow 'steps:
  - uses: actions/checkout@0123456789ab'
  local rc=0
  _check_pins >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
}

test_missing_github_directory_is_usage_error() {
  mkdir -p "$T/empty"
  local rc=0
  AUDIO_UTILS_ACTION_PINS_ROOT="$T/empty" \
    bash "$AU_REPO_ROOT/scripts/check-action-pins.sh" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 2
}

run_tests
