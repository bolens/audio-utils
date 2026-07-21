#!/usr/bin/env bash
# Functional: flac-inventory report content; flac-dupes duplicate detection.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_inventory_writes_report_under_xdg_state() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
  export XDG_STATE_HOME="$T/state"

  run_tool util/flac/flac-inventory/flac-inventory.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "inventory rc ($(tool_out | tail -3))"

  local report="$T/state/audio-utils/flac-inventory/inventory-report.txt"
  assert_file "$report"
  assert_grep "44100" "$report"
  assert_grep "16" "$report"
}

test_dupes_flags_content_duplicates() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture dupe_pair)
  mkdir -p "$T/album"
  cp "$src/"*.flac "$T/album/"

  run_tool util/flac/flac-dupes/flac-dupes.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "dupes must be flagged ($(tool_out | tail -3))"
  assert_grep "duplicate" "$T/failures.log"
}

test_dupes_fingerprint_mode_flags_duplicates() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  command -v fpcalc >/dev/null 2>&1 || skip "missing dependency: fpcalc"
  local src
  src=$(fixture dupe_pair)
  mkdir -p "$T/album"
  cp "$src/"*.flac "$T/album/"

  run_tool util/flac/flac-dupes/flac-dupes.sh -j 1 --fingerprint "$T/album"
  assert_eq "$(tool_rc)" 1 "fingerprint dupes rc ($(tool_out | tail -3))"
}

test_dupes_passes_distinct_files() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"

  run_tool util/flac/flac-dupes/flac-dupes.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "distinct files rc ($(tool_out | tail -3))"
}

run_tests
