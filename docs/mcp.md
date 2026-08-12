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
| Paths | Explicit `paths` (≥1) or `input_file` (`-f`) required. No implicit `AUDIO_UTILS_ROOTS` batch from MCP |
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

Per-tool schemas derive common supported controls from each CLI's live help:
`input_file`, deletion/cleanup, clean/retag/overwrite modes, verbosity, and log
paths appear only where the CLI supports them. Every other current or future
tool-specific option remains available losslessly through `args`, using the
exact tokens shown by `tool_help`. Destructive and network options still pass
through the gates above.

`bluray_to_flac` has a typed schema for its disc and preservation controls,
including title/minimum-length selection, checksummed staging, chapter splits,
original-stream preservation, minisign keys, PAR2 recovery data, and sealing.
Archive verification and full audits do not need dummy input paths:

```json
{
  "name": "bluray_to_flac",
  "arguments": {
    "archive_action": "audit",
    "archive_path": "/archive/disc/flac",
    "sign_public_key": "RW..."
  }
}
```

Device conversion likewise accepts `"device": "/dev/sr0"` without `paths`.
The generic `args` array remains available for forward-compatible CLI flags.

Audit tools expose their policy controls as typed MCP fields. In particular,
`archive_audit` exposes `quick`, `public_key`, `snapshot_dir`, and
`baseline_dir`; lossy, silence, path, dynamics, and disc inventory tools expose
their numeric thresholds and report destinations. `album_incomplete` exposes
`duration_ratio` and `no_duration`; `lossy_authenticity` and `rip_log_audit`
expose `strict`. The schemas enforce the same
ranges as the corresponding CLIs while retaining generic `args` compatibility.
The same typed fields are parsed when the audit is invoked through `run_tool`;
its generic schema retains `args` as the discoverable forward-compatible form.

## Direct stdio

```bash
./mcp/server.sh
```

Speaks MCP JSON-RPC with `Content-Length` framing on stdout; logs on stderr.

## Optional npm package

In-repo, private (`mcp/npm/`). Requires Node ≥ 20.

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
| `AUDIO_UTILS_MCP_ALLOWED_HOSTS` | Bound host and loopback aliases |
| `AUDIO_UTILS_MCP_ALLOWED_ORIGINS` | Empty (browser origins rejected) |
| `AUDIO_UTILS_MCP_MAX_SESSIONS` | `64` |
| `AUDIO_UTILS_MCP_SESSION_IDLE_MS` | `900000` (15 minutes) |

The port must be an integer from 1 through 65535. The default loopback bind is
intentional: the gateway has no built-in authentication and exposes tools that
can read or modify files. Put authentication and transport security in front of
it before binding to a non-loopback interface.

`AUDIO_UTILS_MCP_ALLOWED_HOSTS` and `AUDIO_UTILS_MCP_ALLOWED_ORIGINS` are
comma-separated exact values. Configure them explicitly when a reverse proxy
changes the `Host` header or a browser-based client sends `Origin`. Streamable
HTTP sessions are capped and expired after inactivity; open SSE streams are
not considered idle.

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
