#!/usr/bin/env bash
# Unit tests: shared chapter and audio-extension helpers.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_audio_exts() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/audio_exts.sh"
}

_load_chapters() {
  cue_sanitize_filename() { printf '%s\n' "$1"; }
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/chapters.sh"
}

test_audio_ext_presets_are_composed_from_canonical_lists() {
  _load_audio_exts
  assert_eq "$(au_audio_exts_for_preset portable)" "$AU_AUDIO_EXTS_DEFAULT"
  assert_eq "$(au_audio_exts_for_preset pcm)" "$AU_AUDIO_EXTS_PCM"
  assert_eq "$(au_audio_exts_for_preset playlist)" "$AU_AUDIO_EXTS_PLAYLIST"
  assert_eq "$(au_audio_exts_for_preset library)" \
    "$AU_AUDIO_EXTS_DEFAULT $AU_AUDIO_EXTS_PCM $AU_AUDIO_EXTS_ARCHIVE $AU_AUDIO_EXTS_SIDECAR"
}

test_audio_ext_unknown_preset_fails() {
  _load_audio_exts
  assert_exit 1 au_audio_exts_for_preset unknown
}

test_chapters_from_durations_accumulates_and_skips_invalid_rows() {
  _load_chapters
  local got
  got=$(chapters_from_durations <<'EOF'
1.25|Intro
invalid|Ignored
0|Zero
0.0|Also Zero
2|Main
EOF
)
  assert_eq "$got" $'1|0|1.25000000|Intro\n2|1.25000000|3.25000000|Main'
}

test_chapters_write_ffmetadata_rejects_invalid_times_atomically() {
  _load_chapters
  local row
  for row in '-1|2' 'nope|2' '2|1' '2|2' '1|bad'; do
    printf 'keep me\n' >"$T/chapters.ffmeta"
    if printf '1|%s|Bad\n' "$row" \
      | chapters_write_ffmetadata "$T/chapters.ffmeta"; then
      fail "accepted invalid chapter times: $row"
    fi
    assert_eq "$(cat "$T/chapters.ffmeta")" "keep me" "destination preserved"
  done
  if find "$T" -maxdepth 1 -name '.chapters.*' -print -quit | grep -q .; then
    fail "failed chapter write leaked a temporary file"
  fi
}

test_chapters_write_ffmetadata_rounds_and_escapes() {
  _load_chapters
  chapters_write_ffmetadata "$T/chapters.ffmeta" <<'EOF'
1|0.0004|1.2346|A=B; C#D\E
EOF
  assert_grep '^;FFMETADATA1$' "$T/chapters.ffmeta"
  assert_grep '^START=0$' "$T/chapters.ffmeta"
  assert_grep '^END=1235$' "$T/chapters.ffmeta"
  assert_eq "$(tail -n 1 "$T/chapters.ffmeta")" 'title=A\=B\; C\#D\\E'
}

test_chapters_m4b_codec_allowlist() {
  _load_chapters
  chapters_m4b_codec_ok AAC
  chapters_m4b_codec_ok mp4a.40.2
  assert_exit 1 chapters_m4b_codec_ok mp3
}

run_tests
