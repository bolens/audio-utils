#!/usr/bin/env bash
# Functional: playlist-audit, playlist-dedupe, playlist-normalize.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

# Stage one playlist (plus the music tree it references) into $T/<name>/.
_stage_playlist() { # name.m3u
  local src
  src=$(fixture playlists)
  mkdir -p "$T/${1%.m3u}/music"
  cp "$src/music/"*.flac "$T/${1%.m3u}/music/"
  cp "$src/$1" "$T/${1%.m3u}/"
}

test_audit_clean_playlist_passes() {
  require_cmd flock
  _stage_playlist good.m3u
  run_tool util/playlist/playlist-audit/playlist-audit.sh -j 1 "$T/good"
  assert_eq "$(tool_rc)" 0 "clean playlist rc ($(tool_out | tail -3))"
}

test_audit_flags_broken_and_duplicate_entries() {
  require_cmd flock
  _stage_playlist broken.m3u
  run_tool util/playlist/playlist-audit/playlist-audit.sh -j 1 -L "$T/failures.log" "$T/broken"
  assert_eq "$(tool_rc)" 1 "broken playlist rc ($(tool_out | tail -3))"
  assert_grep "broken.m3u" "$T/failures.log"

  _stage_playlist dupes.m3u
  run_tool util/playlist/playlist-audit/playlist-audit.sh -j 1 "$T/dupes"
  assert_eq "$(tool_rc)" 1 "duplicate entries rc"
}

test_dedupe_requires_yes_then_rewrites() {
  require_cmd flock
  _stage_playlist dupes.m3u

  # Without -y the playlist must not be rewritten.
  run_tool util/playlist/playlist-dedupe/playlist-dedupe.sh -j 1 "$T/dupes"
  assert_eq "$(wc -l <"$T/dupes/dupes.m3u")" 3 "no rewrite without -y"

  run_tool util/playlist/playlist-dedupe/playlist-dedupe.sh -j 1 -y "$T/dupes"
  assert_eq "$(tool_rc)" 0 "dedupe -y rc ($(tool_out | tail -3))"
  assert_eq "$(grep -c . "$T/dupes/dupes.m3u")" 2 "dupes dropped"
  assert_eq "$(grep -c "Track One" "$T/dupes/dupes.m3u")" 1 "first kept once"
}

test_normalize_absolute_rewrites_paths() {
  require_cmd flock
  _stage_playlist good.m3u
  run_tool util/playlist/playlist-normalize/playlist-normalize.sh -j 1 --absolute "$T/good"
  assert_eq "$(tool_rc)" 0 "normalize rc ($(tool_out | tail -3))"
  # Every entry now absolute and pointing at existing files.
  local line
  while IFS= read -r line; do
    [[ "$line" == \#* || -z "$line" ]] && continue
    [[ "$line" == /* ]] || fail "entry not absolute: $line"
    assert_file "$line" "normalized entry resolves"
  done <"$T/good/good.m3u"
}

run_tests
