#!/usr/bin/env bash
# Functional: flac-to-ape — encode via mac (Monkey's Audio) and verify the
# decode MD5 round-trip. Gated on the mac binary (install it with
# scripts/ape-codec.sh, or set AUDIO_UTILS_MAC).
# covers: lib/pipeline/ape.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="conversion/flac-to-ape/flac-to-ape.sh"

_require_mac() {
  [[ -n "${AUDIO_UTILS_MAC:-}" ]] && return 0
  command -v mac >/dev/null 2>&1 \
    || skip "no mac binary (run scripts/ape-codec.sh install)"
}

_mk_album() {
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"
}

test_ape_encodes_losslessly_and_verifies() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mac
  _mk_album

  run_tool "$_TOOL" -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.ape"
  assert_eq "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=nk=1:nw=1 "$T/album/track.ape")" "ape" "codec"
  assert_audio_md5_eq "$T/album/track.flac" "$T/album/track.ape"
  # Tagged source: the tag loss must be surfaced, not hidden.
  assert_grep "tags=dropped" "$T/s.csv"
}

test_ape_level_flag_changes_compression() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mac
  _mk_album

  run_tool "$_TOOL" -j 1 -Q insane "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_grep "ape level: insane" "$T/out"
  assert_audio_md5_eq "$T/album/track.flac" "$T/album/track.ape"
}

test_ape_rejects_invalid_level() {
  _mk_album
  run_tool "$_TOOL" -Q superduper "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "invalid level must be rejected"
  assert_grep "invalid APE level" "$T/out"
}

test_ape_skip_existing_dry_run_and_delete() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mac
  _mk_album

  run_tool "$_TOOL" -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/track.ape" "dry run must not convert"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  local before
  before=$(sha256sum "$T/album/track.ape" | awk '{print $1}')
  run_tool "$_TOOL" -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(sha256sum "$T/album/track.ape" | awk '{print $1}')" "$before" \
    "existing ape must not be rebuilt"
  assert_grep "skipped-existing-ok" "$T/s.csv"

  run_tool "$_TOOL" -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 0 "delete-source rc"
  assert_no_file "$T/album/track.flac" "-d must remove the source"
  assert_file "$T/album/track.ape"
}

run_tests
