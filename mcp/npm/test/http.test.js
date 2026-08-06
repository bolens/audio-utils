import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import http from 'node:http';
import net from 'node:net';
import { after, before, test } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { BashMcpSession } from '../lib/bash.js';

let mainGateway;
let baseUrl;

async function unusedPort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const { port } = server.address();
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function waitForHealth(url, getStderr = () => '') {
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${url}/health`);
      if (response.ok) return response.json();
    } catch {
      // Gateway is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`gateway did not become healthy: ${getStderr()}`);
}

async function spawnGateway(env = {}) {
  const port = await unusedPort();
  let stderr = '';
  const child = spawn(process.execPath, ['bin/http.js'], {
    cwd: new URL('..', import.meta.url),
    env: {
      ...process.env,
      AUDIO_UTILS_MCP_HOST: '127.0.0.1',
      AUDIO_UTILS_MCP_PORT: String(port),
      ...env,
    },
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', (chunk) => {
    stderr += chunk;
  });
  const url = `http://127.0.0.1:${port}`;
  await waitForHealth(url, () => stderr);
  return {
    child,
    url,
    async close() {
      if (child.exitCode !== null) return;
      child.kill('SIGTERM');
      await new Promise((resolve) => child.once('exit', resolve));
    },
  };
}

async function connectClient(url = baseUrl) {
  const client = new Client({ name: 'gateway-test', version: '1.0.0' });
  const transport = new StreamableHTTPClientTransport(new URL(`${url}/mcp`));
  await client.connect(transport);
  return client;
}

async function statusWithHeaders(url, headers) {
  return new Promise((resolve, reject) => {
    const request = http.get(url, { headers }, (response) => {
      response.resume();
      response.on('end', () => resolve(response.statusCode));
    });
    request.on('error', reject);
  });
}

before(async () => {
  mainGateway = await spawnGateway({ AUDIO_UTILS_MCP_MAX_SESSIONS: '2' });
  baseUrl = mainGateway.url;
});

after(async () => {
  await mainGateway?.close();
});

test('health reports readiness and repository version', async () => {
  const response = await fetch(`${baseUrl}/health`);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.equal(body.server, 'audio-utils-mcp-http');
  assert.match(body.version, /^\d+\.\d+\.\d+$/);
});

test('concurrent clients share the proxy and enforce capacity', async () => {
  const clients = await Promise.all([connectClient(), connectClient()]);
  try {
    const catalogs = await Promise.all(clients.map((client) => client.listTools()));
    for (const catalog of catalogs) {
      const names = catalog.tools.map(({ name }) => name);
      assert.ok(names.includes('list_catalog'));
      assert.ok(names.includes('flac_verify'));
    }
    await assert.rejects(connectClient(), /capacity|503/i);
  } finally {
    await Promise.all(clients.map((client) => client.close()));
  }
});

test('rejects untrusted hosts and browser origins', async () => {
  assert.equal(await statusWithHeaders(`${baseUrl}/health`, { host: 'evil.example' }), 403);
  assert.equal(
    await statusWithHeaders(`${baseUrl}/health`, { origin: 'https://evil.example' }),
    403,
  );
});

test('applies the shared capacity limit to legacy SSE', async () => {
  const streams = await Promise.all([
    fetch(`${baseUrl}/sse`),
    fetch(`${baseUrl}/sse`),
  ]);
  try {
    const rejected = await fetch(`${baseUrl}/sse`);
    assert.equal(rejected.status, 503);
    const health = await (await fetch(`${baseUrl}/health`)).json();
    assert.equal(health.sessions, 2);
  } finally {
    await Promise.all(streams.map((response) => response.body.cancel()));
  }
});

test('preserves JSON parser client errors', async () => {
  const malformed = await fetch(`${baseUrl}/mcp`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{broken',
  });
  assert.equal(malformed.status, 400);
  assert.equal((await malformed.json()).error.code, -32700);

  const oversized = await fetch(`${baseUrl}/mcp`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ payload: 'x'.repeat(4 * 1024 * 1024) }),
  });
  assert.equal(oversized.status, 413);
});

test('expires abandoned Streamable HTTP sessions', async () => {
  const gateway = await spawnGateway({
    AUDIO_UTILS_MCP_MAX_SESSIONS: '1',
    AUDIO_UTILS_MCP_SESSION_IDLE_MS: '100',
  });
  try {
    const response = await fetch(`${gateway.url}/mcp`, {
      method: 'POST',
      headers: {
        accept: 'application/json, text/event-stream',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2024-11-05',
          capabilities: {},
          clientInfo: { name: 'idle-test', version: '1' },
        },
      }),
    });
    assert.equal(response.status, 200);
    await response.text();
    await new Promise((resolve) => setTimeout(resolve, 250));
    const health = await (await fetch(`${gateway.url}/health`)).json();
    assert.equal(health.sessions, 0);
  } finally {
    await gateway.close();
  }
});

test('rejects requests after the Bash child exits', async () => {
  const session = new BashMcpSession();
  session.child.kill('SIGTERM');
  await new Promise((resolve) => session.child.once('exit', resolve));
  await assert.rejects(
    session.request({ jsonrpc: '2.0', id: 1, method: 'tools/list' }),
    /exited|SIGTERM/,
  );
});

test('invalid ports fail before the gateway starts', async () => {
  const child = spawn(process.execPath, ['bin/http.js'], {
    cwd: new URL('..', import.meta.url),
    env: { ...process.env, AUDIO_UTILS_MCP_PORT: 'not-a-port' },
    stdio: 'ignore',
  });
  const code = await new Promise((resolve) => child.once('exit', resolve));
  assert.notEqual(code, 0);
});
