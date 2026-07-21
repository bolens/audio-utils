#!/usr/bin/env bash
# Unit tests: lib/media/playlist.sh (format detection, paths, URIs, dedupe).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_lib() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/playlist.sh"
}

test_detect_format_by_extension() {
  _load_lib
  assert_eq "$(playlist_detect_format list.m3u)" "m3u"
  assert_eq "$(playlist_detect_format LIST.M3U8)" "m3u"
  assert_eq "$(playlist_detect_format list.pls)" "pls"
  assert_eq "$(playlist_detect_format list.xspf)" "xspf"
}

test_detect_format_by_content() {
  _load_lib
  printf '[playlist]\nFile1=x.flac\n' >"$T/mystery1"
  printf '<?xml version="1.0"?>\n<playlist version="1">\n' >"$T/mystery2"
  printf '#EXTM3U\nx.flac\n' >"$T/mystery3"
  assert_eq "$(playlist_detect_format "$T/mystery1")" "pls"
  assert_eq "$(playlist_detect_format "$T/mystery2")" "xspf"
  assert_eq "$(playlist_detect_format "$T/mystery3")" "m3u"
}

test_resolve_entry_relative_and_absolute() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac"
  assert_eq "$(playlist_resolve_entry "$T" "music/a.flac")" "$T/music/a.flac"
  assert_eq "$(playlist_resolve_entry "$T" "$T/music/a.flac")" "$T/music/a.flac"
}

test_resolve_entry_strips_crlf_and_whitespace() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac"
  assert_eq "$(playlist_resolve_entry "$T" $'  music/a.flac \r')" "$T/music/a.flac"
}

test_to_relative_inside_and_outside() {
  _load_lib
  mkdir -p "$T/base/sub"
  touch "$T/base/sub/a.flac"
  assert_eq "$(playlist_to_relative "$T/base" "$T/base/sub/a.flac")" "sub/a.flac"
  if playlist_to_relative "$T/base/sub" "/elsewhere/b.flac" >/dev/null 2>&1; then
    fail "outside path must fail"
  fi
}

test_file_uri_roundtrip() {
  _load_lib
  mkdir -p "$T/My Music"
  touch "$T/My Music/a b.flac"
  local uri
  uri=$(playlist_file_uri "$T/My Music/a b.flac")
  assert_grep '^file://' "$uri"
  assert_grep '%20' "$uri"
  assert_eq "$(playlist_uri_to_path "$uri")" "$T/My Music/a b.flac"
}

test_parse_m3u_entries() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac" "$T/music/b.flac"
  cat >"$T/list.m3u" <<EOF
#EXTM3U
#EXTINF:123,Song A
music/a.flac
music/b.flac
EOF
  local n
  n=$(playlist_parse "$T/list.m3u" | wc -l)
  assert_eq "$n" "2"
  playlist_parse "$T/list.m3u" | head -1 | cut -d$'\x1f' -f1 >"$T/first"
  assert_grep "music/a.flac" "$T/first"
}

test_dedupe_entries_keeps_first() {
  _load_lib
  local out
  out=$(printf 'a.flac\x1fSong\x1f10\nb.flac\x1fOther\x1f10\na.flac\x1fSong\x1f10\n' \
    | playlist_dedupe_entries)
  assert_eq "$(wc -l <<<"$out")" "2"
}

run_tests
