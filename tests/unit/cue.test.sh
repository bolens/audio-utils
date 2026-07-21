#!/usr/bin/env bash
# Unit tests: lib/media/cue.sh (CUE parsing helpers).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_lib() {
  # cue.sh reports errors via log_err; stub it for standalone sourcing.
  # shellcheck disable=SC2329  # invoked indirectly by the sourced module
  log_err() { echo "$@" >&2; }
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/cue.sh"
}

test_msf_to_sec() {
  _load_lib
  assert_eq "$(cue_msf_to_sec 00:00:00)" "0.00000000"
  assert_eq "$(cue_msf_to_sec 00:02:00)" "2.00000000"
  # 1 min + 30 s + 45 frames (45/75 = 0.6 s)
  assert_eq "$(cue_msf_to_sec 01:30:45)" "90.60000000"
}

test_msf_rejects_malformed() {
  _load_lib
  assert_exit 1 cue_msf_to_sec "123"
  assert_exit 1 cue_msf_to_sec "00:02"
}

test_unquote() {
  _load_lib
  assert_eq "$(cue_unquote '"Hello World"')" "Hello World"
  assert_eq "$(cue_unquote '  "padded"  ')" "padded"
  assert_eq "$(cue_unquote '  bare  ')" "bare"
  assert_eq "$(cue_unquote '"')" '"'
}

test_file_name_from_line() {
  _load_lib
  assert_eq "$(cue_file_name_from_line ' "My Album.flac" WAVE')" "My Album.flac"
  assert_eq "$(cue_file_name_from_line ' image.wav WAVE')" "image.wav"
}

test_sanitize_filename() {
  _load_lib
  assert_eq "$(cue_sanitize_filename 'A/B:C?D*E')" "A_B_C_D_E"
  assert_eq "$(cue_sanitize_filename '  spaced   out  ')" "spaced out"
  assert_eq "$(cue_sanitize_filename 'trailing dots...')" "trailing dots"
  assert_eq "$(cue_sanitize_filename '')" "track"
  assert_eq "$(cue_sanitize_filename '   ')" "track"
  # Illegal chars are replaced (not dropped), so all-slashes is not empty.
  assert_eq "$(cue_sanitize_filename '///')" "___"
}

test_resolve_image_and_list_tracks() {
  _load_lib
  mkdir -p "$T/album"
  : >"$T/album/Image.flac"
  cat >"$T/album/album.cue" <<'EOF'
PERFORMER "Album Artist"
TITLE "Album Title"
FILE "Image.flac" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    PERFORMER "Guest"
    INDEX 01 00:02:00
EOF

  assert_eq "$(cue_resolve_image "$T/album/album.cue")" "$T/album/Image.flac"

  local -a tracks=()
  mapfile -t tracks < <(cue_list_tracks "$T/album/album.cue")
  assert_eq "${#tracks[@]}" 2 "track count"
  assert_eq "${tracks[0]}" "01|One|Album Artist|0.00000000|2.00000000" "track 1"
  # Last track has no END_SEC; track PERFORMER overrides the album one.
  assert_eq "${tracks[1]}" "02|Two|Guest|2.00000000|" "track 2"
}

test_resolve_image_falls_back_by_stem() {
  _load_lib
  mkdir -p "$T/album"
  : >"$T/album/Image.wav"
  # CUE references .flac; only the .wav exists → stem fallback.
  cat >"$T/album/album.cue" <<'EOF'
FILE "Image.flac" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
EOF
  assert_eq "$(cue_resolve_image "$T/album/album.cue")" "$T/album/Image.wav"
}

run_tests
