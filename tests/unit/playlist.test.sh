#!/usr/bin/env bash
# Unit tests: lib/media/playlist.sh (format detection, paths, URIs, dedupe).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_lib() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/xdg.sh"
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

test_parse_m3u_crlf_and_trailing_line_without_newline() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac" "$T/music/b.flac"
  # CRLF line endings, no newline after the final entry.
  printf '#EXTM3U\r\nmusic/a.flac\r\nmusic/b.flac' >"$T/list.m3u"
  assert_eq "$(playlist_parse "$T/list.m3u" | wc -l)" "2"
  assert_not_grep $'\r' "$(playlist_parse "$T/list.m3u")"
}

test_parse_pls_orders_by_index_and_keeps_metadata() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac" "$T/music/b.flac"
  # Entries deliberately out of order; File2 before File1.
  cat >"$T/list.pls" <<EOF
[playlist]
File2=music/b.flac
Title2=Song B
Length2=200
File1=music/a.flac
Title1=Song A
Length1=100
NumberOfEntries=2
Version=2
EOF
  local out
  out=$(playlist_parse "$T/list.pls")
  assert_eq "$(wc -l <<<"$out")" "2"
  assert_eq "$(head -1 <<<"$out" | cut -d$'\x1f' -f2)" "Song A" "index order"
  assert_eq "$(tail -1 <<<"$out" | cut -d$'\x1f' -f3)" "200" "length carried"
}

test_parse_pls_emits_missing_files_too() {
  # parse resolves paths but does not check existence — missing-entry
  # detection is the audit tools' job, so both rows must come through.
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac"
  printf '[playlist]\nFile1=music/a.flac\nFile2=music/gone.flac\n' >"$T/list.pls"
  assert_eq "$(playlist_parse "$T/list.pls" | wc -l)" "2"
  assert_grep "gone.flac" "$(playlist_parse "$T/list.pls")"
}

test_parse_xspf_locations_and_titles() {
  _load_lib
  mkdir -p "$T/My Music"
  touch "$T/My Music/a b.flac" "$T/My Music/c.flac"
  cat >"$T/list.xspf" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<playlist version="1" xmlns="http://xspf.org/ns/0/">
  <trackList>
    <track>
      <location>My%20Music/a%20b.flac</location>
      <title>Spaced Song</title>
    </track>
    <track>
      <location>My Music/c.flac</location>
    </track>
  </trackList>
</playlist>
EOF
  local out
  out=$(playlist_parse "$T/list.xspf")
  assert_eq "$(wc -l <<<"$out")" "2"
  assert_eq "$(head -1 <<<"$out" | cut -d$'\x1f' -f1)" "$T/My Music/a b.flac" \
    "percent-decoded location"
  assert_eq "$(head -1 <<<"$out" | cut -d$'\x1f' -f2)" "Spaced Song"
}

_tsv_two_entries() {
  printf '%s\x1f%s\x1f%s\n' "$T/music/a.flac" "Song A" "100"
  printf '%s\x1f%s\x1f%s\n' "$T/music/b.flac" "" ""
}

test_write_m3u_relative_with_extinf() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac" "$T/music/b.flac"
  _tsv_two_entries | playlist_write m3u "$T/out.m3u" "$T" relative
  assert_grep '^#EXTM3U' "$T/out.m3u"
  assert_grep '^#EXTINF:100,Song A' "$T/out.m3u"
  assert_grep '^music/a.flac' "$T/out.m3u"
  assert_not_grep "^$T" "$T/out.m3u"
}

test_write_m3u_absolute_mode() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac" "$T/music/b.flac"
  _tsv_two_entries | playlist_write m3u "$T/out.m3u" "$T" absolute
  assert_grep "^$T/music/a.flac" "$T/out.m3u"
}

test_write_pls_roundtrips_through_parse() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac" "$T/music/b.flac"
  _tsv_two_entries | playlist_write pls "$T/out.pls" "$T" relative
  assert_grep '^\[playlist\]' "$T/out.pls"
  assert_grep '^NumberOfEntries=2' "$T/out.pls"
  assert_grep '^Title1=Song A' "$T/out.pls"
  local out
  out=$(playlist_parse "$T/out.pls")
  assert_eq "$(wc -l <<<"$out")" "2" "write→parse roundtrip"
  assert_eq "$(head -1 <<<"$out" | cut -d$'\x1f' -f1)" "$T/music/a.flac"
}

test_write_xspf_escapes_xml_and_roundtrips() {
  _load_lib
  mkdir -p "$T/music"
  touch "$T/music/a.flac"
  printf '%s\x1f%s\x1f%s\n' "$T/music/a.flac" "Bed & <Breakfast>" "10" \
    | playlist_write xspf "$T/out.xspf" "$T" relative
  assert_grep 'Bed &amp; &lt;Breakfast&gt;' "$T/out.xspf"
  assert_not_grep '<Breakfast>' "$T/out.xspf"
  local out
  out=$(playlist_parse "$T/out.xspf")
  assert_eq "$(wc -l <<<"$out")" "1" "write→parse roundtrip"
}

test_write_rejects_unknown_format() {
  _load_lib
  if printf 'x\x1f\x1f\n' | playlist_write wpl "$T/out.wpl" "$T" relative \
    2>/dev/null; then
    fail "unknown format must fail"
  fi
}

run_tests
