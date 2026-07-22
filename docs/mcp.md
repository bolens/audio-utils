# MCP server

Dep-free **Bash** MCP stdio server for audio-utils, plus an optional Node package for HTTP/SSE and Cursor install helpers.

## Quick start (Cursor, zero Node)

From the repo clone:

```bash
./mcp/install-cursor.sh          # writes .cursor/mcp.json (project)
# or:
./mcp/install-cursor.sh --user   # writes ~/.cursor/mcp.json
```

Or set Cursor MCP config manually:

```json
{
  "mcpServers": {
    "audio-utils": {
      "command": "/ABS/PATH/audio-utils/mcp/server.sh"
    }
  }
}
```

Restart Cursor (or reload MCP). The server exposes:

- Meta: `list_catalog`, `tool_help`, `run_tool`
- One tool per CLI under `conversion/` and `util/` (hyphens → underscores, e.g. `wav_to_flac`, `flac_verify`)

## Safety model

| Gate | Default |
|------|---------|
| Paths | **Required** (≥1). No pathless `AUDIO_UTILS_ROOTS` batch from MCP |
| Destructive (`-d` / `-D` / `--apply`) | Blocked unless `allow_destructive=true` |
| Network (`tags-lookup`) | Blocked unless `allow_network=true` |
| Jobs | Default `-j 1` |
| Quiet | Default `-q` |
| Output | Stdout/stderr capped at 64 KiB |

Example dry-run:

```json
{
  "name": "flac_verify",
  "arguments": {
    "paths": ["/path/to/album"],
    "dry_run": true
  }
}
```

Or via meta `run_tool` with `"name": "flac-verify"`.

## Direct stdio

```bash
./mcp/server.sh
```

Speaks MCP JSON-RPC with `Content-Length` framing on stdout; logs on stderr.

## Optional npm package

In-repo, private (`mcp/npm/`). Requires Node ≥ 18.

```bash
cd mcp/npm && npm install
./bin/stdio.js                 # spawn Bash server (same as server.sh)
./bin/install-cursor.js        # same as mcp/install-cursor.sh
AUDIO_UTILS_MCP_PORT=8765 ./bin/http.js
```

### HTTP / SSE

| Env | Default |
|-----|---------|
| `AUDIO_UTILS_MCP_HOST` | `127.0.0.1` |
| `AUDIO_UTILS_MCP_PORT` | `8765` |

| Endpoint | Role |
|----------|------|
| `POST`/`GET`/`DELETE` `/mcp` | Streamable HTTP (MCP SDK) |
| `GET` `/sse` + `POST` `/message` | Legacy SSE |
| `GET` `/health` | Liveness JSON |

The HTTP gateway **proxies** to a spawned `mcp/server.sh` child so tool semantics stay single-sourced in Bash.

## Layout

| Path | Role |
|------|------|
| [`mcp/server.sh`](../mcp/server.sh) | Bash MCP stdio server |
| [`mcp/lib.sh`](../mcp/lib.sh) | Framing, JSON helpers, discovery, safety |
| [`mcp/install-cursor.sh`](../mcp/install-cursor.sh) | Write Cursor `mcp.json` |
| [`mcp/npm/`](../mcp/npm/) | Optional Node bins + deps |

## Tests

```bash
make test K=mcp-server
make check-mcp    # shellcheck mcp/*.sh
```
