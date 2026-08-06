import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import net from 'node:net';
import { after, before, test } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

let gateway;
let baseUrl;
let stderr = '';

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

async function waitForHealth(url) {
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
  throw new Error(`gateway did not become healthy: ${stderr}`);
}

async function connectClient() {
  const client = new Client({ name: 'gateway-test', version: '1.0.0' });
  const transport = new StreamableHTTPClientTransport(new URL(`${baseUrl}/mcp`));
  await client.connect(transport);
  return client;
}

before(async () => {
  const port = await unusedPort();
  baseUrl = `http://127.0.0.1:${port}`;
  gateway = spawn(process.execPath, ['bin/http.js'], {
    cwd: new URL('..', import.meta.url),
    env: {
      ...process.env,
      AUDIO_UTILS_MCP_HOST: '127.0.0.1',
      AUDIO_UTILS_MCP_PORT: String(port),
    },
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  gateway.stderr.setEncoding('utf8');
  gateway.stderr.on('data', (chunk) => {
    stderr += chunk;
  });
  const health = await waitForHealth(baseUrl);
  assert.equal(health.ok, true);
});

after(async () => {
  if (!gateway || gateway.exitCode !== null) return;
  gateway.kill('SIGTERM');
  await new Promise((resolve) => gateway.once('exit', resolve));
});

test('health reports the repository version', async () => {
  const response = await fetch(`${baseUrl}/health`);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.server, 'audio-utils-mcp-http');
  assert.match(body.version, /^\d+\.\d+\.\d+$/);
});

test('concurrent clients initialize and list the proxied catalog', async () => {
  const clients = await Promise.all([connectClient(), connectClient()]);
  try {
    const catalogs = await Promise.all(clients.map((client) => client.listTools()));
    for (const catalog of catalogs) {
      const names = catalog.tools.map(({ name }) => name);
      assert.ok(names.includes('list_catalog'));
      assert.ok(names.includes('flac_verify'));
    }
  } finally {
    await Promise.all(clients.map((client) => client.close()));
  }
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
