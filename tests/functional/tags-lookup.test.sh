#!/usr/bin/env bash
# Functional: tags-lookup — real fpcalc fingerprinting, AcoustID response
# handling against a local mock HTTP server (ACOUSTID_API_URL override).
# Gated on fpcalc (chromaprint) and python3 for the mock server.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="util/audio/tags-lookup/tags-lookup.sh"
_MBID="12345678-9abc-def0-1234-56789abcdef0"

_require_lookup_deps() {
  command -v fpcalc >/dev/null 2>&1 || skip "no fpcalc (chromaprint)"
  command -v python3 >/dev/null 2>&1 || skip "no python3 for mock server"
}

# Start a one-shot HTTP server that answers a single GET with the given JSON
# body, then exits. Prints the URL. timeout(1) reaps it if never queried.
_mock_acoustid() { # response-json
  local body_file="$T/mock-body.json" port_file="$T/mock-port"
  printf '%s' "$1" >"$body_file"
  rm -f "$port_file"
  # Detach stdout/stderr: this runs inside $(...) and an inherited stdout pipe
  # would keep the command substitution blocked until the server exits.
  timeout 20 python3 - "$port_file" "$body_file" <<'PY' >/dev/null 2>&1 &
import http.server, socketserver, sys

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = open(sys.argv[2], "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass

with socketserver.TCPServer(("127.0.0.1", 0), H) as srv:
    with open(sys.argv[1], "w") as f:
        f.write(str(srv.server_address[1]))
    srv.handle_request()
PY
  local i
  for i in $(seq 1 50); do
    [[ -s "$port_file" ]] && break
    sleep 0.1
  done
  [[ -s "$port_file" ]] || fail "mock server did not start"
  printf 'http://127.0.0.1:%s/v2/lookup\n' "$(cat "$port_file")"
}

# fpcalc rejects very short audio ("Empty fingerprint"), so build a dedicated
# 10 s track instead of reusing the 2 s fixture.
_mk_track() { # dest.flac [mbid]
  ffmpeg -nostdin -v error -y \
    -f lavfi -i "anoisesrc=color=pink:duration=10:sample_rate=44100" \
    -ac 2 -c:a flac "$1"
  [[ -z "${2:-}" ]] || metaflac --set-tag="MUSICBRAINZ_TRACKID=$2" "$1"
}

_run_lookup() { # url dir
  ACOUSTID_API_URL="$1" run_tool "$_TOOL" \
    --client-key=testkey --delay 0 -j 1 -L "$T/fails.log" "$2"
}

test_lookup_passes_when_embedded_mbid_matches() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_lookup_deps
  mkdir -p "$T/album"
  _mk_track "$T/album/track.flac" "$_MBID"
  local url
  url=$(_mock_acoustid \
    '{"status":"ok","results":[{"id":"acoustid-1","recordings":[{"id":"'"$_MBID"'"}]}]}')

  _run_lookup "$url" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_grep "mbid matches" "$T/out"
}

test_lookup_flags_mbid_mismatch() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_lookup_deps
  mkdir -p "$T/album"
  _mk_track "$T/album/track.flac" "$_MBID"
  local url
  url=$(_mock_acoustid \
    '{"status":"ok","results":[{"recordings":[{"id":"ffffffff-ffff-ffff-ffff-ffffffffffff"}]}]}')

  _run_lookup "$url" "$T/album"
  assert_eq "$(tool_rc)" 1 "mismatch must fail"
  assert_grep "embedded MBID not in acoustid results" "$T/fails.log"
}

test_lookup_flags_missing_embedded_mbid() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_lookup_deps
  mkdir -p "$T/album"
  _mk_track "$T/album/track.flac"
  local url
  url=$(_mock_acoustid \
    '{"status":"ok","results":[{"recordings":[{"id":"'"$_MBID"'"}]}]}')

  _run_lookup "$url" "$T/album"
  assert_eq "$(tool_rc)" 1 "missing tag must fail"
  assert_grep "missing MUSICBRAINZ_TRACKID" "$T/fails.log"
}

test_lookup_handles_error_response() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_lookup_deps
  mkdir -p "$T/album"
  _mk_track "$T/album/track.flac" "$_MBID"
  local url
  url=$(_mock_acoustid '{"status":"error","error":{"message":"invalid API key"}}')

  _run_lookup "$url" "$T/album"
  assert_eq "$(tool_rc)" 1 "error response must fail"
  assert_grep "acoustid error response" "$T/fails.log"
}

test_lookup_requires_client_key() {
  mkdir -p "$T/album"
  run_tool "$_TOOL" "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "missing client key must be rejected"
  assert_grep "client key required" "$T/out"
}

test_lookup_dry_run_makes_no_request() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_lookup_deps
  mkdir -p "$T/album"
  _mk_track "$T/album/track.flac" "$_MBID"

  # Unroutable TEST-NET address: any attempted request would fail loudly.
  ACOUSTID_API_URL="http://192.0.2.1/v2/lookup" run_tool "$_TOOL" \
    --client-key=testkey -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc ($(tool_out | tail -3))"
  assert_grep "would acoustid-lookup" "$T/out"
}

run_tests
