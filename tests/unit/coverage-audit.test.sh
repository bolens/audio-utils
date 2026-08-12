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

test_tool_coverage_requires_execution_evidence() {
  local copy out rc=0
  copy="$T/repo"
  mkdir -p "$copy/scripts" "$copy/tests/functional" "$copy/tests/unit" \
    "$copy/tests/smoke" "$copy/conversion/comment-only/lib" "$copy/lib/core"
  cp "$_AUDIT" "$copy/scripts/coverage-audit.sh"
  : >"$copy/conversion/comment-only/Makefile"
  printf '#!/usr/bin/env bash\n' >"$copy/conversion/comment-only/comment-only.sh"
  printf '#!/usr/bin/env bash\n' >"$copy/conversion/comment-only/lib/plugin.sh"
  printf '# comment-only is mentioned, but never executed\ntest_placeholder() { :; }\n' \
    >"$copy/tests/functional/example.test.sh"
  : >"$copy/tests/coverage-exempt.tsv"
  out=$(cd "$copy" && bash scripts/coverage-audit.sh --goal 100 2>&1) || rc=$?
  assert_eq "$rc" 1
  assert_grep 'conversion/comment-only' "$out"
  assert_grep 'uncovered:.*1' "$out"
}

run_tests
