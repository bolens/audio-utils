#!/usr/bin/env bash
# Unit tests: repository-local Markdown link checker.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_check_docs() {
  AUDIO_UTILS_DOCS_ROOT="$T/repo" bash "$AU_REPO_ROOT/scripts/check-docs.sh"
}

test_docs_check_handles_newlines_in_markdown_filenames() {
  mkdir -p "$T/repo/docs"
  printf '# Target\n' >"$T/repo/docs/target.md"
  printf '[target](target.md)\n' >"$T/repo/docs/guide"$'\n'"notes.md"
  _check_docs
}

test_docs_check_reports_broken_link() {
  mkdir -p "$T/repo"
  printf '[missing](nope.md)\n' >"$T/repo/README.md"
  local out rc=0
  out=$(_check_docs 2>&1) || rc=$?
  assert_eq "$rc" 1
  assert_grep 'broken local link' "$out"
}

test_docs_check_handles_parentheses_in_link_destination() {
  mkdir -p "$T/repo/docs"
  printf '# Target\n' >"$T/repo/docs/target (live).md"
  printf '[target](docs/target%%20(live).md)\n' >"$T/repo/README.md"
  _check_docs
}

run_tests
