#!/usr/bin/env bash
# Functional: playlist-generate (one m3u per dir) and playlist-export
# (materialize onto a device tree).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_setup_album() {
  local src
  src=$(fixture album)
  mkdir -p "$T/Great Album"
  cp "$src/album/"*.flac "$T/Great Album/"
}

test_generate_writes_m3u_with_relative_entries() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  run_tool util/playlist/playlist-generate/playlist-generate.sh -j 1 "$T/Great Album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local m3u="$T/Great Album/Great Album.m3u"
  assert_file "$m3u"
  assert_eq "$(grep -c '\.flac$' "$m3u")" 3 "3 tracks listed"
  assert_grep "01 - Track One.flac" "$m3u"
  # Entries must be relative (portable playlists).
  assert_not_grep "^/" "$m3u"
}

test_generate_keeps_existing_m3u_without_overwrite() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  printf '# custom playlist\n' >"$T/Great Album/Great Album.m3u"

  run_tool util/playlist/playlist-generate/playlist-generate.sh -j 1 "$T/Great Album"
  assert_eq "$(tool_rc)" 0
  assert_grep "custom playlist" "$T/Great Album/Great Album.m3u" \
    "existing m3u must survive without -y"

  run_tool util/playlist/playlist-generate/playlist-generate.sh -j 1 -y "$T/Great Album"
  assert_eq "$(tool_rc)" 0 "-y rc"
  assert_not_grep "custom playlist" "$T/Great Album/Great Album.m3u"
  assert_grep "01 - Track One.flac" "$T/Great Album/Great Album.m3u"
}

test_generate_dry_run_writes_nothing() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  run_tool util/playlist/playlist-generate/playlist-generate.sh -n "$T/Great Album"
  assert_eq "$(tool_rc)" 0
  assert_no_file "$T/Great Album/Great Album.m3u"
}

test_export_copies_entries_and_rewrites_playlist() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture playlists)
  mkdir -p "$T/pl"
  cp -a "$src/music" "$T/pl/music"
  sed "s|^music/|$T/pl/music/|" "$src/good.m3u" >"$T/pl/good.m3u"

  run_tool util/playlist/playlist-export/playlist-export.sh -j 1 \
    --dest="$T/device" "$T/pl"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/device/good/01 - Track One.flac"
  assert_file "$T/device/good/03 - Track Three.flac"
  assert_file "$T/device/good/good.m3u"
  # Rewritten playlist points at the copied files, relative to destdir.
  assert_grep "01 - Track One.flac" "$T/device/good/good.m3u"
  assert_not_grep "$T/pl/music" "$T/device/good/good.m3u"
}

test_export_number_prefixes_play_order() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture playlists)
  mkdir -p "$T/pl"
  cp -a "$src/music" "$T/pl/music"
  sed "s|^music/|$T/pl/music/|" "$src/good.m3u" >"$T/pl/good.m3u"

  run_tool util/playlist/playlist-export/playlist-export.sh -j 1 \
    --dest="$T/device" --number "$T/pl"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/device/good/001 - 01 - Track One.flac"
  assert_file "$T/device/good/003 - 03 - Track Three.flac"
}

test_export_fails_on_missing_entries() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture playlists)
  mkdir -p "$T/pl"
  cp -a "$src/music" "$T/pl/music"
  sed "s|^music/|$T/pl/music/|" "$src/broken.m3u" >"$T/pl/broken.m3u"

  run_tool util/playlist/playlist-export/playlist-export.sh -j 1 \
    --dest="$T/device" -L "$T/fails.log" "$T/pl"
  assert_eq "$(tool_rc)" 1 "missing entry must fail"
  assert_grep "missing" "$T/fails.log"
  # The present entry is still exported.
  assert_file "$T/device/broken/01 - Track One.flac"
}

test_export_requires_dest() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture playlists)
  mkdir -p "$T/pl"
  cp "$src/good.m3u" "$T/pl/"
  run_tool util/playlist/playlist-export/playlist-export.sh "$T/pl"
  assert_eq "$(tool_rc)" 2 "--dest is mandatory"
}

run_tests
