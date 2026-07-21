#!/usr/bin/env bash
# Unit tests: lib/media/tags.sh (tag normalization helpers).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_lib() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/tags.sh"
}

test_track_number_zero_padded() {
  _load_lib
  assert_eq "$(flac_tag_normalize_track 1)" "01"
  assert_eq "$(flac_tag_normalize_track 9)" "09"
  assert_eq "$(flac_tag_normalize_track 12)" "12"
  assert_eq "$(flac_tag_normalize_track 01)" "01"
}

test_track_number_with_total() {
  _load_lib
  assert_eq "$(flac_tag_normalize_track 1/12)" "01/12"
  assert_eq "$(flac_tag_normalize_track " 3 / 10 ")" "03/10"
}

test_track_number_non_numeric_unchanged() {
  _load_lib
  assert_eq "$(flac_tag_normalize_track A)" "A"
  assert_eq "$(flac_tag_normalize_track "")" ""
}

test_date_keeps_year() {
  _load_lib
  assert_eq "$(flac_tag_normalize_date 1997)" "1997"
  assert_eq "$(flac_tag_normalize_date 2020-05-01)" "2020-05-01"
  assert_eq "$(flac_tag_normalize_date 2020-05)" "2020-05"
}

test_date_strips_iso_time() {
  _load_lib
  assert_eq "$(flac_tag_normalize_date "2020-05-01T12:34:56")" "2020-05-01"
}

test_date_other_values_unchanged() {
  _load_lib
  assert_eq "$(flac_tag_normalize_date "circa 1970")" "circa 1970"
}

test_junk_tag_detection() {
  _load_lib
  flac_tag_is_junk ENCODER || fail "ENCODER is junk"
  flac_tag_is_junk itunnorm || fail "iTunes tags are junk"
  flac_tag_is_junk ENCODED-BY || fail "ENCODED-BY is junk"
  if flac_tag_is_junk ARTIST; then fail "ARTIST is not junk"; fi
  if flac_tag_is_junk ALBUM; then fail "ALBUM is not junk"; fi
}

test_path_component_sanitized() {
  _load_lib
  assert_eq "$(flac_path_component "AC/DC")" "AC_DC"
}

run_tests
