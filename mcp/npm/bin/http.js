#!/usr/bin/env node
/**
 * audio-utils-mcp-http — Streamable HTTP + legacy SSE gateway over Bash MCP stdio.
 *
 * Env:
 *   AUDIO_UTILS_MCP_HOST  default 127.0.0.1
 *   AUDIO_UTILS_MCP_PORT  default 8765
 *
 * Endpoints:
 *   POST/GET/DELETE /mcp  — Streamable HTTP (MCP SDK)
 *   GET /sse              — legacy SSE (MCP SDK)
 *   POST /message         — legacy SSE message endpoint
 */
import { randomUUID } from 'node:crypto';
import express from 'express';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { SSEServerTransport } from '@modelcontextprotocol/sdk/server/sse.js';
import {
  CallToolRequestSchema,
  isInitializeRequest,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { BashMcpSession } from '../lib/bash.js';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const host = process.env.AUDIO_UTILS_MCP_HOST || '127.0.0.1';
const port = Number(process.env.AUDIO_UTILS_MCP_PORT || 8765);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('AUDIO_UTILS_MCP_PORT must be an integer from 1 to 65535');
}

function readVersion() {
  try {
    const vpath = path.resolve(__dirname, '..', '..', '..', 'VERSION');
    return readFileSync(vpath, 'utf8').trim() || '0.0.0';
  } catch {
    return '0.0.0';
  }
}

const bash = new BashMcpSession();
let initializePromise;

async function ensureInitialized() {
  if (!initializePromise) {
    initializePromise = (async () => {
      const response = await bash.request({
        jsonrpc: '2.0',
        id: 0,
        method: 'initialize',
        params: {
          protocolVersion: '2024-11-05',
          capabilities: {},
          clientInfo: { name: 'audio-utils-mcp-http', version: readVersion() },
        },
      });
      if (response.error) {
        throw new Error(response.error.message || 'Bash MCP initialization failed');
      }
      bash.notify({ jsonrpc: '2.0', method: 'notifications/initialized' });
    })().catch((error) => {
      initializePromise = undefined;
      throw error;
    });
  }
  await initializePromise;
}

function createProxyServer() {
  const server = new Server(
    { name: 'audio-utils', version: readVersion() },
    { capabilities: { tools: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    await ensureInitialized();
    const resp = await bash.request({
      jsonrpc: '2.0',
      id: randomUUID(),
      method: 'tools/list',
    });
    if (resp.error) throw new Error(resp.error.message || 'tools/list failed');
    return resp.result;
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    await ensureInitialized();
    const resp = await bash.request({
      jsonrpc: '2.0',
      id: randomUUID(),
      method: 'tools/call',
      params: request.params,
    });
    if (resp.error) {
      return {
        isError: true,
        content: [{ type: 'text', text: resp.error.message || 'tools/call failed' }],
      };
    }
    return resp.result;
  });

  return server;
}

const app = express();
app.use(express.json({ limit: '4mb' }));
const asyncRoute = (handler) => (req, res, next) => {
  Promise.resolve(handler(req, res, next)).catch(next);
};

/** @type {Map<string, SSEServerTransport>} */
const sseTransports = new Map();
/** @type {Map<string, {transport: StreamableHTTPServerTransport, server: Server}>} */
const streamableSessions = new Map();

app.post('/mcp', asyncRoute(async (req, res) => {
  const sessionId = req.headers['mcp-session-id'];
  let session = sessionId ? streamableSessions.get(String(sessionId)) : undefined;
  if (!session && !sessionId && isInitializeRequest(req.body)) {
    const server = createProxyServer();
    let transport;
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (id) => {
        streamableSessions.set(id, { transport, server });
      },
    });
    transport.onclose = () => {
      const id = transport.sessionId;
      if (id) streamableSessions.delete(id);
      server.close().catch(() => {});
    };
    session = { transport, server };
    await server.connect(transport);
  }
  if (!session) {
    res.status(400).json({
      jsonrpc: '2.0',
      error: { code: -32000, message: 'Bad Request: No valid session ID provided' },
      id: null,
    });
    return;
  }
  await session.transport.handleRequest(req, res, req.body);
}));

app.get('/mcp', asyncRoute(async (req, res) => {
  const session = streamableSessions.get(String(req.headers['mcp-session-id'] || ''));
  if (!session) {
    res.status(400).send('Invalid or missing session ID');
    return;
  }
  await session.transport.handleRequest(req, res);
}));

app.delete('/mcp', asyncRoute(async (req, res) => {
  const session = streamableSessions.get(String(req.headers['mcp-session-id'] || ''));
  if (!session) {
    res.status(400).send('Invalid or missing session ID');
    return;
  }
  await session.transport.handleRequest(req, res);
}));

app.get('/sse', asyncRoute(async (req, res) => {
  const server = createProxyServer();
  const transport = new SSEServerTransport('/message', res);
  sseTransports.set(transport.sessionId, transport);
  res.on('close', () => {
    sseTransports.delete(transport.sessionId);
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });
  await server.connect(transport);
}));

app.post('/message', asyncRoute(async (req, res) => {
  const sessionId = req.query.sessionId;
  const transport = sseTransports.get(String(sessionId || ''));
  if (!transport) {
    res.status(400).send('Unknown session');
    return;
  }
  await transport.handlePostMessage(req, res, req.body);
}));

app.get('/health', (_req, res) => {
  res.json({ ok: true, server: 'audio-utils-mcp-http', version: readVersion() });
});

app.use((error, _req, res, _next) => {
  console.error(error);
  if (!res.headersSent) {
    res.status(500).json({ error: 'Internal MCP gateway error' });
  }
});

const httpServer = app.listen(port, host, () => {
  if (host !== '127.0.0.1' && host !== '::1' && host !== 'localhost') {
    console.error('warning: MCP gateway is listening beyond loopback without built-in authentication');
  }
  console.error(
    `audio-utils-mcp-http listening on http://${host}:${port} (/mcp streamable, /sse legacy)`,
  );
});

async function shutdown() {
  await Promise.allSettled([
    ...[...streamableSessions.values()].map(({ transport }) => transport.close()),
    ...[...sseTransports.values()].map((transport) => transport.close()),
  ]);
  bash.close();
  httpServer.close(() => process.exit(0));
}
process.on('SIGINT', () => void shutdown());
process.on('SIGTERM', () => void shutdown());
