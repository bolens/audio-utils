#!/usr/bin/env bash
# Functional: disc finders support the NUL-delimited convert-all contract.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_assert_print0_paths() {
  local finder=$1
  shift
  local item
  local -a found=()
  while IFS= read -r -d '' item; do
    found+=("$item")
  done < <("$AU_REPO_ROOT/$finder" --print0 "$T/root")
  assert_eq "${#found[@]}" "$#"
  local i=0
  for item in "$@"; do
    assert_eq "${found[i]}" "$item"
    ((i += 1))
  done
}

test_dvd_finder_preserves_newline_path() {
  local dir=$'DVD\nLive/VIDEO_TS'
  mkdir -p "$T/root/$dir"
  _assert_print0_paths conversion/dvd-to-flac/find-video_ts-dirs.sh \
    "$T/root/$dir"
}

test_bluray_finder_preserves_newline_path() {
  local dir=$'Blu-ray\nLive/BDMV'
  mkdir -p "$T/root/$dir"
  _assert_print0_paths conversion/bluray-to-flac/find-bdmv-dirs.sh \
    "$T/root/$dir"
}

test_disc_inventory_finder_combines_and_deduplicates_units() {
  local album=$'Album\nLive'
  mkdir -p "$T/root/A/VIDEO_TS" "$T/root/B/BDMV" "$T/root/$album"
  : >"$T/root/$album/disc.cue"
  _assert_print0_paths util/audit/disc-inventory/find-disc-units.sh \
    "$T/root/A/VIDEO_TS" "$T/root/$album" "$T/root/B/BDMV"
}

test_disc_finder_honors_option_terminator() {
  mkdir -p "$T/root/-archive/VIDEO_TS"
  local item extra=0
  IFS= read -r -d '' item < <(
    cd "$T/root"
    "$AU_REPO_ROOT/conversion/dvd-to-flac/find-video_ts-dirs.sh" \
      --print0 -- -archive
  ) || fail "finder emitted no NUL-delimited path"
  assert_eq "$item" "./-archive/VIDEO_TS"
  while IFS= read -r -d '' item; do
    ((extra += 1))
  done < <(
    cd "$T/root"
    "$AU_REPO_ROOT/conversion/dvd-to-flac/find-video_ts-dirs.sh" \
      --print0 -- -archive
  )
  assert_eq "$extra" "1"
}

test_disc_finder_rejects_unknown_options() {
  assert_exit 2 "$AU_REPO_ROOT/conversion/dvd-to-flac/find-video_ts-dirs.sh" \
    --bogus 2>/dev/null
}

run_tests
