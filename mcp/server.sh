#!/usr/bin/env bash
# audio-utils MCP server — JSON-RPC over stdio (Content-Length framing).
#
# Dep-free: bash 4.3+ only. Discovers conversion/ and util/ CLIs and exposes
# one MCP tool per CLI plus list_catalog, tool_help, and run_tool.
#
# Usage:
#   mcp/server.sh
#   # Cursor mcp.json:
#   #   "command": "/ABS/PATH/audio-utils/mcp/server.sh"
#
# Exit: 0 on clean EOF; 1 on fatal setup error.

set -euo pipefail

MCP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$MCP_DIR/lib.sh"

AU_MCP_ROOT=$(mcp_repo_root) || exit 1
mcp_discover "$AU_MCP_ROOT"

mcp_log() {
  printf 'audio-utils-mcp: %s\n' "$*" >&2
}

mcp_log "ready version=$(mcp_version) tools=${#MCP_TOOL_NAMES[@]} (+3 meta)"

while true; do
  req=
  if ! mcp_read_message req; then
    break
  fi
  [[ -n "$req" ]] || continue

  resp=
  resp=$(mcp_dispatch "$req") || {
    mcp_log "dispatch failed"
    continue
  }
  [[ -n "$resp" ]] || continue
  mcp_write_message "$resp"
done

exit 0
