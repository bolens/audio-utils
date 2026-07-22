#!/usr/bin/env bash
# Install audio-utils MCP into Cursor mcp.json (dep-free Bash; optional python3 merge).
#
# Usage:
#   mcp/install-cursor.sh           # write <repo>/.cursor/mcp.json (project)
#   mcp/install-cursor.sh --user    # write ~/.cursor/mcp.json
#   mcp/install-cursor.sh --dry-run # print target + JSON, do not write
#   mcp/install-cursor.sh -h
#
# Merges the "audio-utils" server entry when python3 is available; otherwise
# writes a fresh document (existing file saved as .bak).

set -euo pipefail

MCP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVER="$MCP_DIR/server.sh"
REPO_ROOT=$(cd "$MCP_DIR/.." && pwd)

MODE=project # project | user
DRY_RUN=0

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (($# > 0)); do
  case "$1" in
    --user) MODE=user; shift ;;
    --project) MODE=project; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h | --help) usage 0 ;;
    -*)
      echo "unknown option: $1" >&2
      usage 2
      ;;
    *)
      echo "unexpected arg: $1" >&2
      usage 2
      ;;
  esac
done

[[ -f "$SERVER" ]] || {
  echo "missing $SERVER" >&2
  exit 1
}
chmod +x "$SERVER" "$MCP_DIR/install-cursor.sh" 2>/dev/null || true
SERVER_ABS=$(cd "$(dirname "$SERVER")" && pwd)/$(basename "$SERVER")

if [[ "$MODE" == user ]]; then
  TARGET="${HOME}/.cursor/mcp.json"
else
  TARGET="${REPO_ROOT}/.cursor/mcp.json"
fi

# shellcheck source=lib.sh
source "$MCP_DIR/lib.sh"
ENTRY_JSON=$(printf '{"command":%s}' "$(mcp_json_string "$SERVER_ABS")")

build_doc() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys, os
target, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.isfile(target) and os.path.getsize(target) > 0:
    try:
        with open(target, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}
if not isinstance(data, dict):
    data = {}
servers = data.get("mcpServers")
if not isinstance(servers, dict):
    servers = {}
servers["audio-utils"] = {"command": cmd}
data["mcpServers"] = servers
print(json.dumps(data, indent=2))
' "$TARGET" "$SERVER_ABS"
  else
    printf '{\n  "mcpServers": {\n    "audio-utils": %s\n  }\n}\n' "$ENTRY_JSON"
  fi
}

DOC=$(build_doc)

echo "target: $TARGET"
if ((DRY_RUN)); then
  printf '%s\n' "$DOC"
  exit 0
fi

mkdir -p "$(dirname "$TARGET")"
if [[ -f "$TARGET" ]]; then
  cp -a "$TARGET" "${TARGET}.bak"
fi
printf '%s\n' "$DOC" >"$TARGET"
echo "wrote audio-utils MCP → $TARGET"
echo "command: $SERVER_ABS"
