#!/usr/bin/env bash
# Unit tests: mcp/lib.sh + mcp/server.sh (framing, catalog, safety gates).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_mcp() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/mcp/lib.sh"
  mcp_discover "$AU_REPO_ROOT"
}

_frame() {
  local body=$1
  local -i len
  len=$(printf '%s' "$body" | wc -c)
  printf 'Content-Length: %d\r\n\r\n%s' "$len" "$body"
}

_rpc() {
  # Send one or more framed bodies to server.sh; print response bodies (one per line via read loop into files).
  local out=$1
  shift
  {
    local body
    for body in "$@"; do
      _frame "$body"
    done
  } | "$AU_REPO_ROOT/mcp/server.sh" 2>"$T/mcp-err.txt" >"$out"
}

_read_all_messages() {
  # Read all Content-Length messages from file $1 into $T/msg.N files; set MCP_MSG_COUNT.
  local infile=$1
  MCP_MSG_COUNT=0
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/mcp/lib.sh"
  exec 3<"$infile"
  while true; do
    local msg=
    if ! mcp_read_message msg <&3; then
      break
    fi
    [[ -n "$msg" ]] || continue
    MCP_MSG_COUNT=$((MCP_MSG_COUNT + 1))
    printf '%s' "$msg" >"$T/msg.$MCP_MSG_COUNT"
  done
  exec 3<&-
}

test_mcp_json_escape_and_string() {
  _load_mcp
  assert_eq "$(mcp_json_escape 'a"b')" 'a\"b'
  assert_eq "$(mcp_json_string $'line\nx')" '"line\nx"'
}

test_mcp_json_get_string_and_id() {
  _load_mcp
  local req='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"run_tool"}}'
  assert_eq "$(mcp_json_get_string "$req" method)" "tools/call"
  assert_eq "$(mcp_id_json "$req")" "7"
  local params
  params=$(mcp_json_get_object "$req" params)
  assert_eq "$(mcp_json_get_string "$params" name)" "run_tool"
}

test_mcp_json_string_array() {
  _load_mcp
  local obj='{"paths":["/a","/b/c"],"x":1}'
  local got
  got=$(mcp_json_get_string_array "$obj" paths | paste -sd, -)
  assert_eq "$got" "/a,/b/c"
}

test_mcp_discover_catalog() {
  _load_mcp
  ((${#MCP_TOOL_NAMES[@]} >= 50)) || fail "expected many tools, got ${#MCP_TOOL_NAMES[@]}"
  mcp_resolve_index flac-verify >/dev/null || fail "missing flac-verify"
  mcp_resolve_index wav_to_flac >/dev/null || fail "missing wav_to_flac"
  mcp_resolve_index tags-lookup >/dev/null || fail "missing tags-lookup"
  local cat
  cat=$(mcp_catalog_text)
  assert_grep "flac-verify" "$cat"
  assert_grep "wav-to-flac" "$cat"
}

test_mcp_safety_destructive_and_network() {
  _load_mcp
  if mcp_check_run_safety flac-verify false false -- -d 2>"$T/err"; then
    fail "expected destructive reject"
  fi
  assert_grep "allow_destructive" "$T/err"

  if mcp_check_run_safety tags-lookup false false -- 2>"$T/err"; then
    fail "expected network reject"
  fi
  assert_grep "allow_network" "$T/err"

  mcp_check_run_safety flac-verify true false -- -d
  mcp_check_run_safety tags-lookup false true --
}

test_mcp_framing_roundtrip_helpers() {
  _load_mcp
  local body='{"jsonrpc":"2.0","id":1,"result":{"ok":true}}'
  mcp_write_message "$body" >"$T/framed"
  local msg=
  mcp_read_message msg <"$T/framed"
  assert_eq "$msg" "$body"
}

test_mcp_server_initialize_and_tools_list() {
  _rpc "$T/out" \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  _read_all_messages "$T/out"
  ((MCP_MSG_COUNT >= 2)) || fail "expected ≥2 responses, got $MCP_MSG_COUNT"
  assert_grep '"name":"audio-utils"' "$T/msg.1"
  assert_grep '"name":"list_catalog"' "$T/msg.2"
  assert_grep '"name":"flac_verify"' "$T/msg.2"
  assert_grep '"name":"wav_to_flac"' "$T/msg.2"
  assert_grep '"name":"run_tool"' "$T/msg.2"
}

test_mcp_server_rejects_destructive_run_tool() {
  _rpc "$T/out" \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"run_tool","arguments":{"name":"flac-verify","paths":["/tmp"],"args":["-d"]}}}'
  _read_all_messages "$T/out"
  ((MCP_MSG_COUNT >= 2)) || fail "expected ≥2 responses"
  assert_grep 'allow_destructive' "$T/msg.2"
  assert_grep '"error"' "$T/msg.2"
}

test_mcp_server_rejects_tags_lookup_without_network() {
  _rpc "$T/out" \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
    '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"tags_lookup","arguments":{"paths":["/tmp"]}}}'
  _read_all_messages "$T/out"
  ((MCP_MSG_COUNT >= 2)) || fail "expected ≥2 responses"
  assert_grep 'allow_network' "$T/msg.2"
}

test_mcp_server_unknown_tool() {
  _rpc "$T/out" \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
    '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"run_tool","arguments":{"name":"no-such-tool","paths":["/tmp"]}}}'
  _read_all_messages "$T/out"
  ((MCP_MSG_COUNT >= 2)) || fail "expected ≥2 responses"
  assert_grep 'unknown tool' "$T/msg.2"
}

test_mcp_server_list_catalog_call() {
  _rpc "$T/out" \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
    '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"list_catalog","arguments":{}}}'
  _read_all_messages "$T/out"
  ((MCP_MSG_COUNT >= 2)) || fail "expected ≥2 responses"
  assert_grep 'flac-verify' "$T/msg.2"
  assert_grep '"content"' "$T/msg.2"
}

test_mcp_npm_stdio_smoke() {
  command -v node >/dev/null 2>&1 || skip "node not installed"
  [[ -d "$AU_REPO_ROOT/mcp/npm/node_modules" ]] || skip "mcp/npm deps not installed"
  local body='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"npm-test","version":"0"}}}'
  _frame "$body" | timeout 10 node "$AU_REPO_ROOT/mcp/npm/bin/stdio.js" >"$T/out" 2>"$T/err" || true
  # Server stays up until EOF; with pipe EOF it should exit after one response
  _read_all_messages "$T/out"
  ((MCP_MSG_COUNT >= 1)) || fail "npm stdio produced no MCP response"
  assert_grep '"name":"audio-utils"' "$T/msg.1"
}

run_tests
