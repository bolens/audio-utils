#!/usr/bin/env bash
# Functional: lib/cli/find-audio-dirs.sh directory discovery.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_FIND="$AU_REPO_ROOT/lib/cli/find-audio-dirs.sh"

_mk_tree() {
  mkdir -p "$T/lib/Album One" "$T/lib/Album Two/CD1" "$T/lib/Art Only" "$T/lib/empty"
  : >"$T/lib/Album One/track.wav"
  : >"$T/lib/Album One/track2.WAV"
  : >"$T/lib/Album Two/CD1/a.wav"
  : >"$T/lib/Album Two/CD1/b.aiff"
  : >"$T/lib/Art Only/cover.jpg"
}

test_finds_dirs_with_matching_ext_only() {
  _mk_tree
  local out
  out=$("$_FIND" --ext wav "$T/lib")
  assert_eq "$(wc -l <<<"$out")" 2 "two wav dirs: $out"
  assert_grep "Album One" "$out"
  assert_grep "Album Two/CD1" "$out"
  assert_not_grep "Art Only" "$out"
  assert_not_grep "empty" "$out"
}

test_extension_match_is_case_insensitive_and_dot_tolerant() {
  _mk_tree
  rm "$T/lib/Album One/track.wav"   # leave only the uppercase .WAV
  local out
  out=$("$_FIND" --ext .WaV "$T/lib")
  assert_grep "Album One" "$out"
}

test_multiple_extensions_union() {
  _mk_tree
  local out
  out=$("$_FIND" -e aiff -e flac "$T/lib")
  assert_eq "$(wc -l <<<"$out")" 1
  assert_grep "Album Two/CD1" "$out"
}

test_dir_listed_once_despite_multiple_matches() {
  _mk_tree
  local out
  out=$("$_FIND" -e wav -e aiff "$T/lib")
  assert_eq "$(grep -c "Album Two/CD1" <<<"$out")" 1 "dedup"
}

test_roots_from_env_when_no_args() {
  _mk_tree
  local out
  out=$(AUDIO_UTILS_ROOTS="$T/lib" "$_FIND" --ext wav)
  assert_grep "Album One" "$out"
}

test_symlinked_dirs_not_followed() {
  _mk_tree
  mkdir -p "$T/outside"
  : >"$T/outside/hidden.wav"
  ln -s "$T/outside" "$T/lib/linked"
  local out
  out=$("$_FIND" --ext wav "$T/lib")
  # Note: $T itself contains the test name (and thus "linked"), so match the
  # symlink path specifically.
  assert_not_grep "lib/linked" "$out"
}

test_usage_errors_exit_two() {
  _mk_tree
  assert_exit 2 "$_FIND" "$T/lib" 2>/dev/null            # no --ext
  assert_exit 2 "$_FIND" --ext 2>/dev/null               # missing value
  assert_exit 2 "$_FIND" --ext wav "$T/does-not-exist" 2>/dev/null
  assert_exit 2 env -u AUDIO_UTILS_ROOTS -u WAV2FLAC_ROOTS \
    "$_FIND" --ext wav 2>/dev/null                       # no roots at all
}

test_help_and_version_exit_zero() {
  assert_exit 0 "$_FIND" --help 2>/dev/null
  local out
  out=$("$_FIND" --version)
  assert_grep "find-audio-dirs" "$out"
}

run_tests
