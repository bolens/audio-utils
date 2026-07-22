# audio-utils-mcp (optional)

Node ≥ 18 launcher and HTTP/SSE gateway for the dep-free Bash MCP server in
[`../server.sh`](../server.sh). See [docs/mcp.md](../../docs/mcp.md).

```bash
npm install
./bin/stdio.js
./bin/install-cursor.js --dry-run
AUDIO_UTILS_MCP_PORT=8765 ./bin/http.js
```

Package is `"private": true` (in-repo only; not published).
