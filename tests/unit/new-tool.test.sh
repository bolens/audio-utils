#!/usr/bin/env bash
# Unit tests: scripts/new-tool.sh validation and generated layout.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_setup_generator() {
  mkdir -p "$T/repo/scripts"
  cp -- "$AU_REPO_ROOT/scripts/new-tool.sh" "$T/repo/scripts/new-tool.sh"
  chmod +x "$T/repo/scripts/new-tool.sh"
}

test_scaffolds_valid_utility() {
  _setup_generator
  "$T/repo/scripts/new-tool.sh" util custom album-check m4a >"$T/out"
  local dir="$T/repo/util/custom/album-check"
  assert_file "$dir/album-check.sh"
  assert_file "$dir/find-m4a-dirs.sh"
  assert_file "$dir/lib/plugin.sh"
  assert_grep '^AU_SOURCE_EXT=m4a$' "$dir/lib/plugin.sh"
  [[ -x "$dir/album-check.sh" ]] || fail "entry script is not executable"
}

test_scaffolds_valid_converter() {
  _setup_generator
  "$T/repo/scripts/new-tool.sh" converter foo-to-bar >"$T/out"
  local dir="$T/repo/conversion/foo-to-bar"
  assert_file "$dir/foo-to-bar.sh"
  assert_file "$dir/find-foo-dirs.sh"
  assert_grep '^AU_DEST_EXT=bar$' "$dir/lib/plugin.sh"
}

test_rejects_unsafe_or_ambiguous_components() {
  _setup_generator
  local -a cases=(
    'util ../../escape tool flac'
    'util category ../tool flac'
    'util category tool ../flac'
    'util category trailing- flac'
    'converter foo-to-bar-to-baz'
    'converter foo-to-bar extra'
    'util category tool flac extra'
  )
  local spec rc
  for spec in "${cases[@]}"; do
    rc=0
    # Deliberate word splitting turns each fixed test vector into argv.
    # shellcheck disable=SC2086
    "$T/repo/scripts/new-tool.sh" $spec >"$T/out" 2>"$T/err" || rc=$?
    assert_eq "$rc" 2 "reject: $spec"
  done
  [[ ! -e "$T/escape" ]] || fail "category traversal escaped repository"
}

run_tests
