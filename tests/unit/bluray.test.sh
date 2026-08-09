#!/usr/bin/env bash
# Unit tests: Blu-ray path discovery and internal media transport.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_bluray() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/pipeline/bluray.sh"
  log_err() { :; }
  log_note() { :; }
}

test_plain_media_print0_preserves_newline_and_sort_order() {
  _load_bluray
  local first=$'A\nLive.mkv' second='B.m2ts' item
  local -a found=()
  mkdir -p "$T/media"
  : >"$T/media/$second"
  : >"$T/media/$first"
  while IFS= read -r -d '' item; do
    found+=("$item")
  done < <(bluray_list_plain_media --print0 "$T/media")
  assert_eq "${#found[@]}" "2"
  assert_eq "${found[0]}" "$T/media/$first"
  assert_eq "${found[1]}" "$T/media/$second"
}

test_decrypt_plain_media_emits_nul_records() {
  _load_bluray
  bluray_media_readable() { [[ $1 != *unreadable* ]]; }
  local good=$'Good\nTitle.mkv' bad='unreadable.mkv' item
  local -a found=()
  mkdir -p "$T/media" "$T/out"
  : >"$T/media/$good"
  : >"$T/media/$bad"
  while IFS= read -r -d '' item; do
    found+=("$item")
  done < <(bluray_decrypt_or_copy "$T/media" "$T/out")
  assert_eq "${#found[@]}" "1"
  assert_eq "${found[0]}" "$T/media/$good"
}

test_resolve_media_dir_with_many_files_under_pipefail() {
  _load_bluray
  mkdir -p "$T/media"
  local i
  for ((i = 0; i < 200; i++)); do
    : >"$T/media/title-$i.mkv"
  done
  assert_eq "$(bluray_resolve_input "$T/media")" "media_dir"
}

run_tests
