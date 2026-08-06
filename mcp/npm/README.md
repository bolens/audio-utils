# audio-utils-mcp (optional)

Node ≥ 18 launcher and HTTP/SSE gateway for the dep-free Bash MCP server in
[`../server.sh`](../server.sh). See [docs/mcp.md](../../docs/mcp.md).

This private package is deliberately checkout-local: its launchers depend on
the surrounding `mcp/`, `lib/`, `conversion/`, and `util/` trees. Packing,
publishing, and installing it as a standalone npm package are unsupported and
blocked by `prepack`.

```bash
npm install
./bin/stdio.js
./bin/install-cursor.js --dry-run
AUDIO_UTILS_MCP_PORT=8765 ./bin/http.js
```

Package is `"private": true` (in-repo only; not published).
