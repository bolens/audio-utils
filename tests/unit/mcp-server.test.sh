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

test_mcp_json_getters_only_match_top_level_keys() {
  _load_mcp
  local obj='{"text":"\"allow_destructive\":true","nested":{"allow_destructive":true},"allow_destructive":false}'
  assert_eq "$(mcp_json_get_bool "$obj" allow_destructive)" false
  if mcp_json_get_string '{"nested":{"name":"wrong"}}' name >/dev/null; then
    fail "nested key must not match"
  fi
  mcp_parse_run_args_from_json \
    '{"args":["\"allow_destructive\":true"],"allow_destructive":false}'
  assert_eq "$MCP_ARG_ALLOW_DESTRUCTIVE" false "argument text cannot enable deletion"
}

test_mcp_json_scalar_getters_require_delimiters() {
  _load_mcp
  assert_eq "$(mcp_json_get_bool '{"flag":true}' flag)" true
  assert_eq "$(mcp_json_get_number '{"jobs":12.5}' jobs)" 12.5
  mcp_json_get_null_or_missing '{"value":null}' value || fail "valid null rejected"
  assert_exit 1 mcp_json_get_bool '{"flag":truejunk}' flag
  assert_exit 1 mcp_json_get_bool '{"flag":false0}' flag
  assert_exit 1 mcp_json_get_number '{"jobs":12.5oops}' jobs
  assert_exit 1 mcp_json_get_null_or_missing '{"value":nullish}' value
}

test_mcp_json_decodes_unicode_escapes() {
  _load_mcp
  assert_eq "$(mcp_json_parse_string '"M\u00fasica"')" "Música"
  assert_eq "$(mcp_json_parse_string '"disc \ud83d\udcbf"')" "disc 💿"
  assert_eq "$(mcp_json_get_string '{"path":"M\u00fasica\/a.flac"}' path)" \
    "Música/a.flac"
}

test_mcp_json_rejects_invalid_escapes() {
  _load_mcp
  local value
  for value in '"bad\q"' '"bad\u12xy"' '"bad\ud83d"' \
    '"bad\ud83d\u0041"' '"bad\udcbf"' '"nul\u0000"'; do
    if mcp_json_parse_string "$value" >/dev/null; then
      fail "accepted invalid JSON string: $value"
    fi
  done
}

test_mcp_json_string_array() {
  _load_mcp
  local obj='{"paths":["/a","-leading","line\nfeed","M\u00fasica"],"x":1}'
  local item
  local -a got=()
  while IFS= read -r -d '' item; do
    got+=("$item")
  done < <(mcp_json_get_string_array "$obj" paths)
  assert_eq "${#got[@]}" 4
  assert_eq "${got[0]}" "/a"
  assert_eq "${got[1]}" "-leading"
  assert_eq "${got[2]}" $'line\nfeed'
  assert_eq "${got[3]}" "Música"
}

test_mcp_json_string_array_rejects_bad_separators() {
  _load_mcp
  local obj
  for obj in '{"paths":["/a" "/b"]}' '{"paths":["/a",]}' \
    '{"paths":[,"/a"]}' '{"paths":["/a",,"/b"]}'; do
    if mcp_json_get_string_array "$obj" paths >/dev/null; then
      fail "accepted malformed array: $obj"
    fi
  done
}

test_mcp_run_args_preserve_newline_paths() {
  _load_mcp
  mcp_parse_run_args_from_json \
    '{"name":"flac-verify","paths":["line\nfeed.flac"],"args":["--","-x"]}'
  assert_eq "${#MCP_ARG_PATHS[@]}" 1
  assert_eq "${MCP_ARG_PATHS[0]}" $'line\nfeed.flac'
  assert_eq "${#MCP_ARG_ARGS[@]}" 2
  assert_eq "${MCP_ARG_ARGS[1]}" '-x'
  assert_exit 1 mcp_parse_run_args_from_json '{"paths":["/a",]}'
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

test_mcp_framing_preserves_bytes_and_boundaries() {
  _load_mcp
  local first=$'{"name":"Música"}\n' second='{"id":2}' message=
  {
    _frame "$first"
    _frame "$second"
  } >"$T/frames"
  exec 3<"$T/frames"
  mcp_read_message message <&3
  assert_eq "$message" "$first" "trailing newline preserved"
  mcp_read_message message <&3
  assert_eq "$message" "$second" "UTF-8 length did not consume next frame"
  exec 3<&-
}

test_mcp_framing_rejects_truncated_body() {
  _load_mcp
  printf 'Content-Length: 10\r\n\r\nshort' >"$T/truncated"
  local message=unchanged
  if mcp_read_message message <"$T/truncated"; then
    fail "truncated frame accepted"
  fi
  assert_eq "$message" unchanged "partial body must not escape"
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
