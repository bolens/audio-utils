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
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { BashMcpSession } from '../lib/bash.js';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const host = process.env.AUDIO_UTILS_MCP_HOST || '127.0.0.1';
const port = Number(process.env.AUDIO_UTILS_MCP_PORT || 8765);

function readVersion() {
  try {
    const vpath = path.resolve(__dirname, '..', '..', '..', 'VERSION');
    return readFileSync(vpath, 'utf8').trim() || '0.0.0';
  } catch {
    return '0.0.0';
  }
}

const bash = new BashMcpSession();
let initialized = false;

async function ensureInitialized() {
  if (initialized) return;
  await bash.request({
    jsonrpc: '2.0',
    id: 0,
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'audio-utils-mcp-http', version: readVersion() },
    },
  });
  bash.notify({ jsonrpc: '2.0', method: 'notifications/initialized' });
  initialized = true;
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

/** @type {Map<string, SSEServerTransport>} */
const sseTransports = new Map();

app.all('/mcp', async (req, res) => {
  const server = createProxyServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => randomUUID(),
  });
  res.on('close', () => {
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.get('/sse', async (req, res) => {
  const server = createProxyServer();
  const transport = new SSEServerTransport('/message', res);
  sseTransports.set(transport.sessionId, transport);
  res.on('close', () => {
    sseTransports.delete(transport.sessionId);
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });
  await server.connect(transport);
});

app.post('/message', async (req, res) => {
  const sessionId = req.query.sessionId;
  const transport = sseTransports.get(String(sessionId || ''));
  if (!transport) {
    res.status(400).send('Unknown session');
    return;
  }
  await transport.handlePostMessage(req, res, req.body);
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, server: 'audio-utils-mcp-http', version: readVersion() });
});

const httpServer = app.listen(port, host, () => {
  console.error(
    `audio-utils-mcp-http listening on http://${host}:${port} (/mcp streamable, /sse legacy)`,
  );
});

function shutdown() {
  bash.close();
  httpServer.close();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
