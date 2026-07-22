#!/usr/bin/env bash
# Functional: rip-log-audit, album-incomplete, lossy-authenticity,
# classical-tags, hardlink-dupes, playlist-smart, silence-split, silence-trim.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

# --- rip-log-audit -----------------------------------------------------------

_write_eac_ok_log() {
  cat >"$1" <<'EOF'
Exact Audio Copy V1.6 from 23. July 2020

EAC extraction logfile from 1. January 2024, 12:00

Read mode               : Secure
Utilize accurate stream : Yes
Defeat audio cache      : Yes
Make use of C2 pointers : No

Track  1
     Filename 01.wav
     Peak level 95.0 %
     Test CRC A1B2C3D4
     Copy CRC A1B2C3D4
     Accurately ripped (confidence 10)
     Copy OK

All tracks accurately ripped

No errors occurred
EOF
}

_write_eac_bad_log() {
  cat >"$1" <<'EOF'
Exact Audio Copy V1.6 from 23. July 2020

EAC extraction logfile from 1. January 2024, 12:00

Read mode               : Burst
Utilize accurate stream : No

Track  1
     Suspicious position 0:01:23
     Copy aborted

There were errors
EOF
}

test_rip_log_audit_ok_and_bad() {
  require_cmd flock grep awk
  mkdir -p "$T/album"
  _write_eac_ok_log "$T/album/Album.log"
  run_tool util/audit/rip-log-audit/rip-log-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean eac log ($(tool_out | tail -3))"

  _write_eac_bad_log "$T/album/Bad.log"
  run_tool util/audit/rip-log-audit/rip-log-audit.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "bad eac log rc ($(tool_out | tail -3))"
  assert_grep "not-secure\\|rip-errors\\|unknown-ripper" "$T/failures.log"
}

test_rip_log_audit_unknown_ripper() {
  require_cmd flock grep awk
  mkdir -p "$T/album"
  printf 'this is not a ripper log\njust text\n' >"$T/album/notes.log"
  run_tool util/audit/rip-log-audit/rip-log-audit.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "unknown ripper rc"
  assert_grep "unknown-ripper" "$T/failures.log"
}

# --- album-incomplete --------------------------------------------------------

test_album_incomplete_clean_and_gaps() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/clean" "$T/gap"
  cp "$src/album/"*.flac "$T/clean/"
  # Fixture album already has contiguous tracks — complete.
  run_tool util/audit/album-incomplete/album-incomplete.sh -j 1 --no-duration "$T/clean"
  assert_eq "$(tool_rc)" 0 "complete album rc ($(tool_out | tail -3))"

  cp "$src/album/01 - Track One.flac" "$T/gap/"
  cp "$src/album/02 - Track Two.flac" "$T/gap/"
  metaflac --remove-tag=TRACKNUMBER --set-tag="TRACKNUMBER=1" \
    --remove-tag=TOTALTRACKS --set-tag="TOTALTRACKS=3" -- "$T/gap/01 - Track One.flac"
  metaflac --remove-tag=TRACKNUMBER --set-tag="TRACKNUMBER=3" \
    --remove-tag=TOTALTRACKS --set-tag="TOTALTRACKS=3" -- "$T/gap/02 - Track Two.flac"
  run_tool util/audit/album-incomplete/album-incomplete.sh -j 1 --no-duration \
    -L "$T/failures.log" "$T/gap"
  assert_eq "$(tool_rc)" 1 "gap album rc ($(tool_out | tail -3))"
  assert_grep "track-gaps\\|incomplete-tracks" "$T/failures.log"
}

test_album_incomplete_discs() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/disc"
  cp "$src/album/01 - Track One.flac" "$T/disc/a.flac"
  metaflac --remove-tag=DISCNUMBER --set-tag="DISCNUMBER=1" \
    --remove-tag=TOTALDISCS --set-tag="TOTALDISCS=2" \
    --remove-tag=TRACKNUMBER --set-tag="TRACKNUMBER=1" \
    --remove-tag=TOTALTRACKS --set-tag="TOTALTRACKS=1" -- "$T/disc/a.flac"
  run_tool util/audit/album-incomplete/album-incomplete.sh -j 1 --no-duration \
    -L "$T/failures.log" "$T/disc"
  assert_eq "$(tool_rc)" 1 "incomplete discs rc"
  assert_grep "incomplete-discs" "$T/failures.log"
}

# --- lossy-authenticity ------------------------------------------------------

test_lossy_authenticity_runs_on_mp3() {
  require_cmd ffmpeg ffprobe flock awk
  local src
  src=$(fixture lossy)
  mkdir -p "$T/lossy"
  cp "$src/track.mp3" "$T/lossy/"
  # Low-bitrate sine fixture is expected inconclusive or genuine (not brickwall-vs-320).
  run_tool util/audit/lossy-authenticity/lossy-authenticity.sh -j 1 "$T/lossy"
  # Exit 0 (genuine/inconclusive) is fine; if it somehow suspects, still exercised the path.
  local rc
  rc=$(tool_rc)
  [[ "$rc" == 0 || "$rc" == 1 ]] || fail "unexpected rc=$rc ($(tool_out | tail -5))"
}

# --- classical-tags ----------------------------------------------------------

test_classical_tags_split_and_apply() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src work movement
  src=$(fixture album)
  mkdir -p "$T/classical"
  cp "$src/album/01 - Track One.flac" "$T/classical/sym.flac"
  metaflac --remove-tag=GENRE --set-tag="GENRE=Classical" \
    --remove-tag=TITLE --set-tag="TITLE=Symphony No. 5: I. Allegro" \
    --remove-tag=COMPOSER --set-tag="COMPOSER=Beethoven" \
    --remove-tag=WORK --remove-tag=MOVEMENT --remove-tag=MOVEMENTNUMBER \
    -- "$T/classical/sym.flac"

  run_tool util/audio/classical-tags/classical-tags.sh -j 1 -L "$T/failures.log" \
    "$T/classical"
  assert_eq "$(tool_rc)" 1 "report needs normalize rc"
  assert_grep "split-work\\|WORK=" "$T/failures.log"

  run_tool util/audio/classical-tags/classical-tags.sh -j 1 --apply "$T/classical"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  work=$(metaflac --show-tag=WORK -- "$T/classical/sym.flac" | sed 's/^WORK=//')
  movement=$(metaflac --show-tag=MOVEMENT -- "$T/classical/sym.flac" | sed 's/^MOVEMENT=//')
  assert_eq "$work" "Symphony No. 5" "WORK tag"
  assert_eq "$movement" "Allegro" "MOVEMENT tag"
}

test_classical_tags_skips_non_classical() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/rock"
  cp "$src/album/01 - Track One.flac" "$T/rock/"
  metaflac --remove-tag=GENRE --set-tag="GENRE=Rock" \
    --remove-tag=COMPOSER --remove-tag=WORK -- "$T/rock/"*.flac
  run_tool util/audio/classical-tags/classical-tags.sh -j 1 "$T/rock"
  assert_eq "$(tool_rc)" 0 "skip non-classical rc"
}

# --- hardlink-dupes ----------------------------------------------------------

test_hardlink_dupes_report_and_apply() {
  require_cmd flac metaflac flock ln
  local src ino1 ino2
  src=$(fixture album)
  mkdir -p "$T/dupes"
  cp "$src/album/01 - Track One.flac" "$T/dupes/a.flac"
  cp "$src/album/01 - Track One.flac" "$T/dupes/b.flac"

  run_tool util/library/hardlink-dupes/hardlink-dupes.sh -j 1 -L "$T/failures.log" \
    "$T/dupes"
  assert_eq "$(tool_rc)" 1 "candidate rc ($(tool_out | tail -3))"
  assert_grep "hardlink candidate\\|keeper=" "$T/failures.log"

  run_tool util/library/hardlink-dupes/hardlink-dupes.sh -j 1 --apply "$T/dupes"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  ino1=$(stat -c '%i' -- "$T/dupes/a.flac")
  ino2=$(stat -c '%i' -- "$T/dupes/b.flac")
  assert_eq "$ino1" "$ino2" "same inode after hardlink"
}

# --- playlist-smart ----------------------------------------------------------

test_playlist_smart_genre_filter() {
  require_cmd flac metaflac flock
  local src
  src=$(fixture album)
  mkdir -p "$T/lib"
  cp "$src/album/"*.flac "$T/lib/"
  metaflac --remove-tag=GENRE --set-tag="GENRE=Rock" -- "$T/lib/01 - Track One.flac"
  metaflac --remove-tag=GENRE --set-tag="GENRE=Jazz" -- "$T/lib/02 - Track Two.flac"

  run_tool util/playlist/playlist-smart/playlist-smart.sh -j 1 \
    --out "$T/rock.m3u" --genre Rock "$T/lib"
  assert_eq "$(tool_rc)" 0 "smart playlist rc ($(tool_out | tail -5))"
  assert_file "$T/rock.m3u"
  assert_grep "Track One" "$T/rock.m3u"
  if grep -q "Track Two" "$T/rock.m3u"; then
    fail "Jazz track must not appear in Rock playlist"
  fi
}

# --- silence-split -----------------------------------------------------------

test_silence_split_two_tones() {
  require_cmd flac ffmpeg ffprobe flock awk
  mkdir -p "$T/live"
  # 3s tone + 3s silence + 3s tone → two tracks with --silence-sec=1 --min-track=1
  ffmpeg -nostdin -v error -y \
    -f lavfi -i "sine=frequency=440:duration=3:sample_rate=44100" \
    -f lavfi -i "anullsrc=r=44100:cl=stereo:d=3" \
    -f lavfi -i "sine=frequency=880:duration=3:sample_rate=44100" \
    -filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[a]" \
    -map "[a]" -c:a flac "$T/live/set.flac"

  run_tool util/flac/silence-split/silence-split.sh -j 1 \
    --silence-sec=1.0 --min-track=1.0 -y "$T/live"
  assert_eq "$(tool_rc)" 0 "silence-split rc ($(tool_out | tail -5))"
  assert_file "$T/live/set - 01.flac"
  assert_file "$T/live/set - 02.flac"
}

# --- silence-trim ------------------------------------------------------------

test_silence_trim_report_and_apply() {
  require_cmd flac metaflac ffmpeg ffprobe flock awk
  mkdir -p "$T/trim"
  # 2s silence + 2s tone + 2s silence
  ffmpeg -nostdin -v error -y \
    -f lavfi -i "anullsrc=r=44100:cl=stereo:d=2" \
    -f lavfi -i "sine=frequency=440:duration=2:sample_rate=44100" \
    -f lavfi -i "anullsrc=r=44100:cl=stereo:d=2" \
    -filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[a]" \
    -map "[a]" -c:a flac "$T/trim/padded.flac"
  metaflac --set-tag="TITLE=Padded" -- "$T/trim/padded.flac"

  run_tool util/flac/silence-trim/silence-trim.sh -j 1 \
    --silence-sec=0.5 --min-keep=0.5 -L "$T/failures.log" "$T/trim"
  assert_eq "$(tool_rc)" 1 "trim candidate rc ($(tool_out | tail -3))"
  assert_grep "trim candidate" "$T/failures.log"

  run_tool util/flac/silence-trim/silence-trim.sh -j 1 \
    --silence-sec=0.5 --min-keep=0.5 --apply "$T/trim"
  assert_eq "$(tool_rc)" 0 "trim apply rc ($(tool_out | tail -3))"
  assert_eq "$(metaflac --show-tag=TITLE -- "$T/trim/padded.flac" | sed 's/^TITLE=//')" \
    "Padded" "tags preserved"
  local dur
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 -- "$T/trim/padded.flac")
  # Should be roughly 2s (+ pads), not 6s
  awk -v d="$dur" 'BEGIN { exit !(d+0 < 3.5 && d+0 > 1.0) }' || \
    fail "expected trimmed duration ~2s, got $dur"
}

run_tests
