#!/usr/bin/env bash
# Functional: flac-to-tak orchestration via a fake takc shim (AUDIO_UTILS_TAKC).
# The real Takc is proprietary and Windows-only; the shim honors Takc's CLI
# (-e/-d ... IN OUT) so the full convert → decode → MD5-verify flow, preset
# validation, and failure paths run for real. Codec fidelity is NOT covered.
# covers: lib/pipeline/tak.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="conversion/flac-to-tak/flac-to-tak.sh"

# Fake takc: "encodes"/"decodes" by copying, so decode(encode(wav)) == wav
# and the pipeline's MD5 verification legitimately passes.
_mk_shim() { # [decode-corrupts]
  cat >"$T/faketakc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode=""
args=()
for a in "$@"; do
  case "$a" in
    -e) mode=encode ;;
    -d) mode=decode ;;
    -p*|-md5|-v|-overwrite) ;;
    *) args+=("$a") ;;
  esac
done
[[ -n "$mode" && ${#args[@]} -eq 2 ]] || { echo "faketakc: bad args: $*" >&2; exit 2; }
cp -f -- "${args[0]}" "${args[1]}"
# Corruption must drop real samples: extra trailing bytes after the WAV data
# chunk are ignored by the demuxer and would not change the decoded MD5.
if [[ "$mode" == decode && "${FAKETAKC_CORRUPT_DECODE:-0}" -eq 1 ]]; then
  truncate -s -8000 "${args[1]}"
fi
EOF
  chmod +x "$T/faketakc"
}

_run_tak() { # args...
  AUDIO_UTILS_TAKC="$T/faketakc" run_tool "$_TOOL" "$@"
}

_mk_album() {
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"
}

test_tak_encode_verify_flow_with_shim() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _mk_shim
  _mk_album

  _run_tak -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.tak"
  assert_grep "verified" "$T/out"
  # Fixture is tagged; Takc drops tags and the tool must surface that.
  assert_grep "tags=dropped" "$T/s.csv"
}

test_tak_verify_md5_mismatch_fails() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _mk_shim
  _mk_album

  FAKETAKC_CORRUPT_DECODE=1 _run_tak -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "corrupted decode must fail verify"
  assert_grep "TAK verify MD5 mismatch\|takc decode verify failed" "$T/fails.log"
  assert_no_file "$T/album/track.tak" "no artifact on failed verify"
}

test_tak_rejects_invalid_preset() {
  _mk_shim
  mkdir -p "$T/album"
  _run_tak -Q p9 "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "invalid preset must be rejected"
  assert_grep "invalid TAK preset" "$T/out"
}

test_tak_errors_without_takc() {
  mkdir -p "$T/album"
  AUDIO_UTILS_TAKC="$T/does-not-exist" run_tool "$_TOOL" "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "missing takc must be an error"
  assert_grep "AUDIO_UTILS_TAKC not found" "$T/out"
}

test_tak_dry_run_never_calls_takc() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _mk_album
  # Shim that fails loudly if executed at all.
  printf '#!/usr/bin/env bash\necho "takc must not run" >&2\nexit 99\n' >"$T/faketakc"
  chmod +x "$T/faketakc"

  _run_tak -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc ($(tool_out | tail -3))"
  assert_no_file "$T/album/track.tak"
  assert_grep "would convert" "$T/out"
}

run_tests
