#!/usr/bin/env bash
# Functional: library-sync sibling checks; library-prune orphan detection.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

# FLAC master tree $T/flac/album/*.flac + portable mirror $T/portable/album/*.mp3.
_stage_pair() {
  local src lossy f base
  src=$(fixture album)
  lossy=$(fixture lossy)
  mkdir -p "$T/flac/album" "$T/portable/album"
  cp "$src/album/"*.flac "$T/flac/album/"
  for f in "$T/flac/album/"*.flac; do
    base=$(basename -- "$f" .flac)
    cp "$lossy/track.mp3" "$T/portable/album/$base.mp3"
  done
}

test_sync_passes_with_full_mirror() {
  require_cmd flac flock
  _stage_pair
  export AUDIO_UTILS_ROOTS="$T/flac"
  run_tool util/library/library-sync/library-sync.sh -j 1 \
    --portable-root="$T/portable" "$T/flac/album"
  assert_eq "$(tool_rc)" 0 "full mirror rc ($(tool_out | tail -3))"
}

test_sync_flags_missing_sibling() {
  require_cmd flac flock
  _stage_pair
  rm "$T/portable/album/02 - Track Two.mp3"
  export AUDIO_UTILS_ROOTS="$T/flac"
  run_tool util/library/library-sync/library-sync.sh -j 1 -L "$T/failures.log" \
    --portable-root="$T/portable" "$T/flac/album"
  assert_eq "$(tool_rc)" 1 "missing sibling rc ($(tool_out | tail -3))"
  assert_grep "02 - Track Two" "$T/failures.log"
}

test_prune_reports_then_deletes_orphan() {
  require_cmd flock
  _stage_pair
  local lossy
  lossy=$(fixture lossy)
  cp "$lossy/track.mp3" "$T/portable/album/99 - Orphan.mp3"

  run_tool util/library/library-prune/library-prune.sh -j 1 \
    --flac-root="$T/flac" --portable-root="$T/portable" "$T/portable/album"
  assert_eq "$(tool_rc)" 1 "orphan reported ($(tool_out | tail -3))"
  assert_file "$T/portable/album/99 - Orphan.mp3" "report must not delete"

  run_tool util/library/library-prune/library-prune.sh -j 1 -d \
    --flac-root="$T/flac" --portable-root="$T/portable" "$T/portable/album"
  assert_eq "$(tool_rc)" 0 "delete rc ($(tool_out | tail -3))"
  assert_no_file "$T/portable/album/99 - Orphan.mp3"
  assert_file "$T/portable/album/01 - Track One.mp3" "mirrored file must survive"
}

test_prune_clean_mirror_passes() {
  require_cmd flock
  _stage_pair
  run_tool util/library/library-prune/library-prune.sh -j 1 \
    --flac-root="$T/flac" --portable-root="$T/portable" "$T/portable/album"
  assert_eq "$(tool_rc)" 0 "clean mirror rc ($(tool_out | tail -3))"
}

run_tests
