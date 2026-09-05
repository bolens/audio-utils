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
const sessionLimit = Number(process.env.AUDIO_UTILS_MCP_MAX_SESSIONS || 64);
const sessionIdleMs = Number(process.env.AUDIO_UTILS_MCP_SESSION_IDLE_MS || 900_000);
if (!Number.isInteger(sessionLimit) || sessionLimit < 1) {
  throw new Error('AUDIO_UTILS_MCP_MAX_SESSIONS must be a positive integer');
}
if (!Number.isInteger(sessionIdleMs) || sessionIdleMs < 100) {
  throw new Error('AUDIO_UTILS_MCP_SESSION_IDLE_MS must be an integer of at least 100');
}

function csvEnv(name) {
  return (process.env[name] || '').split(',').map((value) => value.trim()).filter(Boolean);
}

const configuredHosts = csvEnv('AUDIO_UTILS_MCP_ALLOWED_HOSTS');
const allowedHosts = new Set(configuredHosts.length ? configuredHosts : [host, `${host}:${port}`]);
if (!configuredHosts.length && ['127.0.0.1', '::1', 'localhost'].includes(host)) {
  for (const loopback of ['127.0.0.1', 'localhost', '[::1]']) {
    allowedHosts.add(loopback);
    allowedHosts.add(`${loopback}:${port}`);
  }
}
const allowedOrigins = new Set(csvEnv('AUDIO_UTILS_MCP_ALLOWED_ORIGINS'));

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
      await bash.notify({ jsonrpc: '2.0', method: 'notifications/initialized' });
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
app.use((req, res, next) => {
  const requestHost = req.headers.host || '';
  if (!allowedHosts.has(requestHost)) {
    res.status(403).json({ error: 'Host not allowed' });
    return;
  }
  const origin = req.headers.origin;
  if (origin && !allowedOrigins.has(origin)) {
    res.status(403).json({ error: 'Origin not allowed' });
    return;
  }
  next();
});
app.use(express.json({ limit: '4mb' }));
const asyncRoute = (handler) => (req, res, next) => {
  Promise.resolve(handler(req, res, next)).catch(next);
};

/** @type {Map<string, SSEServerTransport>} */
const sseTransports = new Map();
/** @type {Map<string, {transport: StreamableHTTPServerTransport, server: Server, timer?: NodeJS.Timeout}>} */
const streamableSessions = new Map();
let pendingSessions = 0;

function forgetSession(id) {
  const session = streamableSessions.get(id);
  if (!session) return;
  if (session.timer) clearTimeout(session.timer);
  streamableSessions.delete(id);
}

function expireSession(id) {
  const session = streamableSessions.get(id);
  if (!session) return;
  forgetSession(id);
  session.transport.close().catch(() => {});
  session.server.close().catch(() => {});
}

function touchSession(id) {
  const session = streamableSessions.get(id);
  if (!session) return;
  if (session.timer) clearTimeout(session.timer);
  session.timer = setTimeout(() => expireSession(id), sessionIdleMs);
  session.timer.unref();
}

function sessionCount() {
  return streamableSessions.size + sseTransports.size + pendingSessions;
}

app.post('/mcp', asyncRoute(async (req, res) => {
  const sessionId = req.headers['mcp-session-id'];
  const requestSessionId = sessionId ? String(sessionId) : '';
  let session = requestSessionId ? streamableSessions.get(requestSessionId) : undefined;
  let pending = false;
  if (!session && !sessionId && isInitializeRequest(req.body)) {
    if (sessionCount() >= sessionLimit) {
      res.status(503).json({
        jsonrpc: '2.0',
        error: { code: -32000, message: 'MCP session capacity reached' },
        id: null,
      });
      return;
    }
    pendingSessions += 1;
    pending = true;
    const server = createProxyServer();
    let transport;
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (id) => {
        streamableSessions.set(id, { transport, server });
        touchSession(id);
      },
    });
    transport.onclose = () => {
      const id = transport.sessionId;
      if (id) forgetSession(id);
      server.close().catch(() => {});
    };
    session = { transport, server };
    try {
      await server.connect(transport);
    } catch (error) {
      pendingSessions -= 1;
      transport.close().catch(() => {});
      server.close().catch(() => {});
      throw error;
    }
  }
  if (!session) {
    res.status(400).json({
      jsonrpc: '2.0',
      error: { code: -32000, message: 'Bad Request: No valid session ID provided' },
      id: null,
    });
    return;
  }
  if (requestSessionId && session.timer) {
    clearTimeout(session.timer);
    session.timer = undefined;
  }
  try {
    await session.transport.handleRequest(req, res, req.body);
  } finally {
    if (pending) pendingSessions -= 1;
    if (requestSessionId) touchSession(requestSessionId);
  }
}));

app.get('/mcp', asyncRoute(async (req, res) => {
  const session = streamableSessions.get(String(req.headers['mcp-session-id'] || ''));
  if (!session) {
    res.status(400).send('Invalid or missing session ID');
    return;
  }
  const id = String(req.headers['mcp-session-id']);
  if (session.timer) clearTimeout(session.timer);
  session.timer = undefined;
  res.on('close', () => touchSession(id));
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
  if (sessionCount() >= sessionLimit) {
    res.status(503).send('MCP session capacity reached');
    return;
  }
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
  const ok = bash.isAlive;
  res.status(ok ? 200 : 503).json({
    ok,
    server: 'audio-utils-mcp-http',
    version: readVersion(),
    sessions: streamableSessions.size + sseTransports.size,
    pendingSessions,
  });
});

app.use((error, _req, res, _next) => {
  console.error(error);
  if (!res.headersSent) {
    const candidate = Number(error.status || error.statusCode);
    const status = candidate >= 400 && candidate < 500 ? candidate : 500;
    if (error instanceof SyntaxError && status === 400) {
      res.status(400).json({
        jsonrpc: '2.0',
        error: { code: -32700, message: 'Parse error' },
        id: null,
      });
      return;
    }
    res.status(status).json({ error: status === 500 ? 'Internal MCP gateway error' : error.message });
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
