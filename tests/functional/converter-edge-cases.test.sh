#!/usr/bin/env bash
# Functional: converter edge cases shared by every pipeline — corrupt input
# must fail with a fail-log row and no output artifact, and filenames with
# unicode, spaces, and shell metacharacters must survive end to end.
# covers: lib/core/log.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_wav_to_flac_garbage_bytes_fail_but_good_file_converts() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  local jobs dir original_bad
  for jobs in 1 2; do
    dir="$T/batch-$jobs"
    mkdir -p "$dir"
    cp "$src/sine.wav" "$dir/zz-good.wav"
    printf 'not a RIFF file' >"$dir/00-garbage.wav"
    original_bad=$(sha256sum -- "$dir/00-garbage.wav")

    run_tool conversion/wav-to-flac/wav-to-flac.sh \
      -j "$jobs" -L "$T/fails-$jobs.log" "$dir"
    assert_eq "$(tool_rc)" 1 "mixed batch must report failure" || return
    assert_grep "00-garbage.wav" "$T/fails-$jobs.log" || return
    assert_not_grep "zz-good.wav" "$T/fails-$jobs.log" || return
    assert_file "$dir/zz-good.flac" "good sibling must still convert" || return
    assert_file "$dir/zz-good.wav" "source must remain" || return
    assert_audio_md5_eq "$src/sine.wav" "$dir/zz-good.flac" || return
    cmp -- "$src/sine.wav" "$dir/zz-good.wav" || return
    assert_eq "$(sha256sum -- "$dir/00-garbage.wav")" "$original_bad" || return
    [[ ! -e "$dir/00-garbage.flac" && ! -L "$dir/00-garbage.flac" ]] || {
      fail "failed input produced output"
      return 1
    }
  done
}

test_unicode_and_metachar_filenames_survive_conversion() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  local dir="$T/Björk — Vespertine (2001) [FLAC]"
  mkdir -p "$dir"
  local name="01 - Café Nöise 空白 & \$tuff; 'quoted'.wav"
  cp "$src/sine.wav" "$dir/$name"

  run_tool conversion/wav-to-flac/wav-to-flac.sh \
    -j 1 -S "$T/s.csv" "$dir"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$dir/${name%.wav}.flac"
  assert_audio_md5_eq "$dir/$name" "$dir/${name%.wav}.flac"
  assert_grep "Café Nöise" "$T/s.csv"
}

test_newline_filename_survives_conversion() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src name
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  name=$'01 - line\nbreak.wav'
  cp "$src/sine.wav" "$T/album/$name"

  run_tool conversion/wav-to-flac/wav-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_file "$T/album/${name%.wav}.flac"
  assert_audio_md5_eq "$T/album/$name" "$T/album/${name%.wav}.flac"
}

test_unicode_filenames_survive_lossy_encode() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/albüm"
  cp "$src/track.flac" "$T/albüm/Träck ¡uno!.flac"

  run_tool conversion/flac-to-mp3/flac-to-mp3.sh -j 1 "$T/albüm"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/albüm/Träck ¡uno!.mp3"
}

test_failed_publication_retains_sources_and_reports_failure() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  local wav flac_source dir tool input_ext output_ext jobs
  wav=$(fixture wav_sine)
  flac_source=$(fixture flac_tagged)
  export AU_TEST_REAL_MV
  AU_TEST_REAL_MV=$(command -v mv)
  mkdir -p "$T/bin"
  cat >"$T/bin/mv" <<'SH'
#!/usr/bin/env bash
if [[ "${!#}" == "$AU_TEST_FAIL_DEST" ]]; then
  printf 'simulated publication failure\n' >&2
  exit 1
fi
exec "$AU_TEST_REAL_MV" "$@"
SH
  chmod +x "$T/bin/mv"
  export PATH="$T/bin:$PATH" AU_TEST_FAIL_DEST
  for jobs in 1 2; do
    for tool in wav-to-flac wav-to-aiff flac-to-wav flac-to-tta tta-to-flac flac-to-mp3; do
      input_ext=${tool%-to-*}
      output_ext=${tool#*-to-}
      dir="$T/$tool-$jobs"
      mkdir -p "$dir"
      case "$input_ext" in
        wav) cp "$wav/sine.wav" "$dir/track.wav" ;;
        flac) cp "$flac_source/track.flac" "$dir/track.flac" ;;
        tta) ffmpeg -v error -i "$flac_source/track.flac" -c:a tta "$dir/track.tta" ;;
      esac
      cp "$dir/track.$input_ext" "$T/original"
      AU_TEST_FAIL_DEST="$dir/track.$output_ext"
      run_tool "conversion/$tool/$tool.sh" -j "$jobs" -d -L "$dir/fails.log" -S "$dir/success.csv" "$dir"
      assert_eq "$(tool_rc)" 1 "$tool jobs=$jobs must fail publication" || return
      assert_grep 'publication failed' "$dir/fails.log" || return
      cmp "$T/original" "$dir/track.$input_ext" || return
      assert_no_file "$AU_TEST_FAIL_DEST" || return
      if [[ -f "$dir/success.csv" ]]; then
        [[ $(wc -l <"$dir/success.csv") -le 1 ]] || { fail "success row after publication failure"; return 1; }
      fi
      assert_not_grep 'verified:' "$(tool_out)" || return
    done
  done
}

test_failed_retag_publication_keeps_existing_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local wav dir="$T/retag"
  wav=$(fixture wav_sine)
  mkdir -p "$dir" "$T/bin"
  cp "$wav/sine.wav" "$dir/track.wav"
  run_tool conversion/wav-to-flac/wav-to-flac.sh -j 1 "$dir"
  assert_eq "$(tool_rc)" 0 || return
  cp "$dir/track.flac" "$T/original.flac"
  export AU_TEST_REAL_MV AU_TEST_FAIL_DEST="$dir/track.flac"
  AU_TEST_REAL_MV=$(command -v mv)
  cat >"$T/bin/mv" <<'SH'
#!/usr/bin/env bash
[[ "${!#}" != "$AU_TEST_FAIL_DEST" ]] || exit 1
exec "$AU_TEST_REAL_MV" "$@"
SH
  chmod +x "$T/bin/mv"
  export PATH="$T/bin:$PATH"
  run_tool conversion/wav-to-flac/wav-to-flac.sh -R -j 1 "$dir"
  assert_eq "$(tool_rc)" 1 || return
  cmp "$T/original.flac" "$dir/track.flac" || return
  cmp "$wav/sine.wav" "$dir/track.wav" || return
  assert_not_grep 'retagged:' "$(tool_out)"
}

run_tests
