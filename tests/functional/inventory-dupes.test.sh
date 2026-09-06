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

test_duplicate_indexes_preserve_newlines_and_tabs() {
  require_cmd flock base64
  local folder register state first result
  for folder in util/audio/audio-dupes util/flac/flac-dupes util/library/hardlink-dupes; do
    (
      # Source-only index functions, isolated per tool to avoid name collisions.
      # shellcheck source=/dev/null
      source "$AU_REPO_ROOT/$folder/lib/convert.sh"
      state="$T/${folder##*/}"
      mkdir -p "$state"
      export AU_DUPES_STATE="$state" AU_HL_STATE="$state"
      register=_dupes_register
      [[ "$folder" != */hardlink-dupes ]] || register=_hl_register
      mkdir "$state/index.tsv"
      assert_exit 2 "$register" content /first.flac
      rmdir "$state/index.tsv"
      first=$'/album\nline\twith whitespace/a.flac'
      assert_exit 1 "$register" content "$first"
      result=$("$register" content '/another/b.flac')
      assert_eq "$result" "$first" "complete keeper path"
      assert_eq "$(wc -l <"$state/index.tsv")" 2 "one record per path"
    )
  done
}

run_tests
