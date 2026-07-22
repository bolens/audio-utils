#!/usr/bin/env bash
# Repeatable audio fixtures for the test suite.
#
# Usage (after sourcing harness.sh):
#   src=$(fixture wav_sine)          # → cached dir; files inside
#   cp "$src/sine.wav" "$T/"
#
# Fixtures are built lazily into tests/.cache/fixtures-v<N>/<name>/ (masters,
# treated as read-only — always copy into the test scratch dir before running
# tools that may write). Bump _AU_FIXTURE_VERSION to invalidate the cache.
#
# Generators need ffmpeg + flac + metaflac; call require_cmd first (fixture
# does it for you and skips the test when they are missing).

_AU_FIXTURE_VERSION=3
AU_FIXTURE_CACHE="${AU_FIXTURE_CACHE:-$AU_REPO_ROOT/tests/.cache/fixtures-v${_AU_FIXTURE_VERSION}}"

# fixture NAME → prints the fixture dir, building it under a lock if needed.
fixture() {
  local name=$1
  local dir="$AU_FIXTURE_CACHE/$name"
  local builder="_fixture_build_${name}"

  declare -F "$builder" >/dev/null || {
    echo "fixture: unknown fixture '$name'" >&2
    return 1
  }

  if [[ ! -e "$dir/.done" ]]; then
    require_cmd ffmpeg flac metaflac flock
    mkdir -p -- "$AU_FIXTURE_CACHE"
    # Cycle guard: a builder re-entering its own fixture (classic cause: a
    # test file redefining a fixtures.sh helper) would self-deadlock on the
    # lock below. Fail loudly instead.
    case ":${_AU_FIXTURE_STACK:-}:" in
      *":$name:"*)
        echo "fixture: recursive build of '$name'" \
          "(stack: ${_AU_FIXTURE_STACK}) — helper name collision?" >&2
        return 1
        ;;
    esac
    # Per-fixture lock: builders may call fixture() recursively for their
    # dependencies (acyclic), so a single global lock would self-deadlock.
    (
      flock -w 300 9 || { echo "fixture: lock timeout: $name" >&2; exit 1; }
      if [[ ! -e "$dir/.done" ]]; then
        rm -rf -- "$dir" "$dir.tmp"
        mkdir -p -- "$dir.tmp"
        export _AU_FIXTURE_STACK="${_AU_FIXTURE_STACK:-}:$name"
        if "$builder" "$dir.tmp" >&2; then
          : >"$dir.tmp/.done"
          mv -T -- "$dir.tmp" "$dir"
        else
          rm -rf -- "$dir.tmp"
          echo "fixture: builder failed: $name" >&2
          exit 1
        fi
      fi
    ) 9>"$dir.lock" || skip "fixture build failed: $name"
  fi
  printf '%s\n' "$dir"
}

_ffq() { ffmpeg -nostdin -v error -y "$@"; }

# Encode WAV→FLAC and apply standard tags. _mk_flac OUT WAV TITLE TRACK [ARTIST] [ALBUM]
_mk_flac() {
  local out=$1 wav=$2 title=$3 track=$4 artist="${5:-Test Artist}" album="${6:-Test Album}"
  flac --totally-silent -f -o "$out" "$wav"
  metaflac --set-tag="ARTIST=$artist" --set-tag="ALBUM=$album" \
    --set-tag="TITLE=$title" --set-tag="TRACKNUMBER=$track" \
    --set-tag="DATE=2020" "$out"
}

# --- builders (each receives its target dir) ---------------------------------

# Little-endian integer as raw bytes on stdout. _le VALUE NBYTES
_le() {
  local v=$1 n=$2 i b oct
  for ((i = 0; i < n; i++)); do
    b=$(((v >> (8 * i)) & 0xff))
    printf -v oct '%03o' "$b"
    # shellcheck disable=SC2059  # octal escape is built, not user input
    printf "\\${oct}"
  done
}

# Hand-crafted stereo DSD64 DSF file (no encoder exists in ffmpeg; the format
# is a simple documented container, so we write the chunks directly).
# _mk_dsf OUT [BLOCKS_PER_CHANNEL]  (4096-byte blocks; 22 ≈ 0.26 s)
_mk_dsf() {
  local out=$1 blocks=${2:-22}
  local ch=2 block=4096
  local data_per_ch=$((blocks * block))
  local samples=$((data_per_ch * 8)) # 1 bit per sample
  local data_bytes=$((data_per_ch * ch))
  local data_chunk=$((12 + data_bytes))
  local total=$((28 + 52 + data_chunk))
  {
    printf 'DSD '; _le 28 8; _le "$total" 8; _le 0 8
    printf 'fmt '; _le 52 8
    _le 1 4        # format version
    _le 0 4        # format id: raw DSD
    _le 2 4        # channel type: stereo
    _le "$ch" 4
    _le 2822400 4  # DSD64 sampling frequency
    _le 1 4        # bits per sample, LSB-first
    _le "$samples" 8
    _le "$block" 4
    _le 0 4        # reserved
    printf 'data'; _le "$data_chunk" 8
  } >"$out"
  # DSD "silence": alternating 01101001 bit pattern (0x69).
  head -c "$data_bytes" /dev/zero | tr '\0' '\151' >>"$out"
}

# Stereo DSD64 DSF (hand-crafted; decodes via ffmpeg dsd_lsbf_planar).
_fixture_build_dsf() {
  local d=$1
  _mk_dsf "$d/tone.dsf"
}

# Short DSDIFF (.dff) via sox (for dsf-to-flac sox fallback path).
# Ubuntu's sox needs libsox-fmt-all for the dff handler; skip builders otherwise.
_fixture_build_dff() {
  local d=$1
  command -v sox >/dev/null 2>&1 || {
    echo "fixture dff: sox required" >&2
    return 1
  }
  sox --help 2>&1 | grep -qE '(^|[[:space:]])dff([[:space:]]|$)' || {
    echo "fixture dff: sox lacks dff handler (install libsox-fmt-all)" >&2
    return 1
  }
  _ffq -f lavfi -i "sine=frequency=440:duration=0.25:sample_rate=44100" \
    -ac 2 -c:a pcm_s16le "$d/tone.wav" || return 1
  sox "$d/tone.wav" "$d/tone.dff" || return 1
  [[ -f "$d/tone.dff" ]] || return 1
  rm -f "$d/tone.wav"
}

# 2s stereo 16-bit 44.1 kHz sine + white noise WAVs.
_fixture_build_wav_sine() {
  local d=$1
  _ffq -f lavfi -i "sine=frequency=440:duration=2:sample_rate=44100" \
    -ac 2 -c:a pcm_s16le "$d/sine.wav"
  _ffq -f lavfi -i "anoisesrc=color=white:duration=2:sample_rate=44100:amplitude=0.5" \
    -ac 2 -c:a pcm_s16le "$d/noise.wav"
}

# Single tagged FLAC (sine) + its source WAV.
_fixture_build_flac_tagged() {
  local d=$1 src
  src=$(fixture wav_sine)
  cp "$src/sine.wav" "$d/sine.wav"
  _mk_flac "$d/track.flac" "$d/sine.wav" "Test Title" 1
}

# Three-track tagged FLAC album directory.
_fixture_build_album() {
  local d=$1 f wav
  local -a freqs=(330 440 550)
  local -a titles=("Track One" "Track Two" "Track Three")
  mkdir -p "$d/album"
  for f in 0 1 2; do
    wav="$d/t$f.wav"
    _ffq -f lavfi -i "sine=frequency=${freqs[$f]}:duration=2:sample_rate=44100" \
      -ac 2 -c:a pcm_s16le "$wav"
    _mk_flac "$d/album/0$((f + 1)) - ${titles[$f]}.flac" "$wav" \
      "${titles[$f]}" "$((f + 1))"
    rm -f "$wav"
  done
}

# FLAC with corrupted audio frames (header intact; flac -t must fail).
_fixture_build_flac_corrupt() {
  local d=$1 src size
  src=$(fixture flac_tagged)
  cp "$src/track.flac" "$d/corrupt.flac"
  size=$(stat -c %s "$d/corrupt.flac")
  dd if=/dev/zero of="$d/corrupt.flac" bs=1 count=256 \
    seek=$((size - 2048)) conv=notrunc status=none
}

# Fake "hi-res": 44.1 kHz white noise upsampled to 96 kHz / 24-bit,
# plus a genuine 96 kHz / 24-bit white-noise FLAC for contrast.
# The steep 20 kHz lowpass mimics real upsampled content: nothing above the
# original Nyquist (a plain aresample leaves too much leakage to detect).
_fixture_build_flac_hires() {
  local d=$1
  _ffq -f lavfi -i "anoisesrc=color=white:duration=2:sample_rate=44100:amplitude=0.5" \
    -ac 2 \
    -af "lowpass=f=20000:poles=2,lowpass=f=20000:poles=2,lowpass=f=20000:poles=2,aresample=96000" \
    -c:a pcm_s24le "$d/fake96.wav"
  flac --totally-silent -f -o "$d/fake96.flac" "$d/fake96.wav"
  rm -f "$d/fake96.wav"
  _ffq -f lavfi -i "anoisesrc=color=white:duration=2:sample_rate=96000:amplitude=0.5" \
    -ac 2 -c:a pcm_s24le "$d/real96.wav"
  flac --totally-silent -f -o "$d/real96.flac" "$d/real96.wav"
  rm -f "$d/real96.wav"
}

# 16-bit content padded into a 24-bit container.
_fixture_build_flac_padded24() {
  local d=$1 src
  src=$(fixture wav_sine)
  _ffq -i "$src/noise.wav" -c:a pcm_s24le "$d/padded.wav"
  flac --totally-silent -f -o "$d/padded24.flac" "$d/padded.wav"
  rm -f "$d/padded.wav"
}

# Tagged lossy files (MP3 via libmp3lame, M4A via native aac).
_fixture_build_lossy() {
  local d=$1 src
  src=$(fixture wav_sine)
  _ffq -i "$src/sine.wav" -c:a libmp3lame -q:a 5 \
    -metadata artist="Test Artist" -metadata album="Test Album" \
    -metadata title="Test Title" -metadata track=1 "$d/track.mp3"
  _ffq -i "$src/sine.wav" -c:a aac -b:a 128k \
    -metadata artist="Test Artist" -metadata album="Test Album" \
    -metadata title="Test Title" -metadata track=1 "$d/track.m4a"
}

# CUE + single-image FLAC album (3 × 2s tracks).
_fixture_build_cue_album() {
  local d=$1 f
  mkdir -p "$d/album"
  for f in 330 440 550; do
    _ffq -f lavfi -i "sine=frequency=$f:duration=2:sample_rate=44100" \
      -ac 2 -c:a pcm_s16le "$d/p$f.wav"
  done
  _ffq -i "$d/p330.wav" -i "$d/p440.wav" -i "$d/p550.wav" \
    -filter_complex "[0:a][1:a][2:a]concat=n=3:v=0:a=1[a]" -map "[a]" \
    -c:a pcm_s16le "$d/image.wav"
  flac --totally-silent -f -o "$d/album/CueAlbum.flac" "$d/image.wav"
  rm -f "$d"/p*.wav "$d/image.wav"
  cat >"$d/album/CueAlbum.cue" <<'EOF'
PERFORMER "Test Artist"
TITLE "Cue Album"
FILE "CueAlbum.flac" WAVE
  TRACK 01 AUDIO
    TITLE "Part One"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Part Two"
    INDEX 01 00:02:00
  TRACK 03 AUDIO
    TITLE "Part Three"
    INDEX 01 00:04:00
EOF
}

# Playlist trees: valid, broken (missing entry), duplicated entries.
_fixture_build_playlists() {
  local d=$1 src
  src=$(fixture album)
  mkdir -p "$d/music"
  cp "$src/album/"*.flac "$d/music/"
  {
    echo "music/01 - Track One.flac"
    echo "music/02 - Track Two.flac"
    echo "music/03 - Track Three.flac"
  } >"$d/good.m3u"
  {
    echo "music/01 - Track One.flac"
    echo "music/does-not-exist.flac"
  } >"$d/broken.m3u"
  {
    echo "music/01 - Track One.flac"
    echo "music/02 - Track Two.flac"
    echo "music/01 - Track One.flac"
  } >"$d/dupes.m3u"
}

# Album dir salted with junk files.
_fixture_build_junk_tree() {
  local d=$1 src
  src=$(fixture album)
  mkdir -p "$d/album"
  cp "$src/album/"*.flac "$d/album/"
  printf 'junk' >"$d/album/Thumbs.db"
  printf 'junk' >"$d/album/.DS_Store"
  printf '\x00\x05\x16\x07junk' >"$d/album/._01 - Track One.flac"
  : >"$d/album/empty.bin"
}

# Two FLACs with identical audio (same STREAMINFO MD5), different names/tags.
_fixture_build_dupe_pair() {
  local d=$1 src
  src=$(fixture wav_sine)
  _mk_flac "$d/original.flac" "$src/sine.wav" "Original" 1
  _mk_flac "$d/copy of original.flac" "$src/sine.wav" "Copy" 2 "Other Artist" "Other Album"
}
