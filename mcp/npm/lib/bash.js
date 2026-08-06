import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Absolute path to mcp/server.sh */
export function serverScriptPath() {
  return path.resolve(__dirname, '..', '..', 'server.sh');
}

/** Absolute path to mcp/install-cursor.sh */
export function installCursorScriptPath() {
  return path.resolve(__dirname, '..', '..', 'install-cursor.sh');
}

/**
 * Spawn the Bash MCP stdio server. Inherits stdio by default for Cursor.
 * @param {{ stdio?: import('node:child_process').StdioOptions }} [opts]
 */
export function spawnBashMcp(opts = {}) {
  const script = serverScriptPath();
  const child = spawn(script, [], {
    stdio: opts.stdio ?? 'inherit',
    env: process.env,
  });
  return child;
}

/**
 * Minimal Content-Length framed JSON-RPC client to a Bash MCP child.
 */
export class BashMcpSession {
  constructor() {
    this._deadError = null;
    this.child = spawn(serverScriptPath(), [], {
      stdio: ['pipe', 'pipe', 'inherit'],
      env: process.env,
    });
    this._buf = Buffer.alloc(0);
    this._waiters = [];
    /** @type {Promise<void>} */
    this._chain = Promise.resolve();
    this.child.stdout.on('data', (chunk) => this._onData(chunk));
    this.child.on('error', (error) => this._markDead(error));
    this.child.on('exit', (code, signal) => {
      this._markDead(new Error(`bash MCP exited (${signal || code})`));
    });
    this.child.stdin.on('error', (error) => this._markDead(error));
  }

  _markDead(error) {
    if (this._deadError) return;
    this._deadError = error;
    for (const waiter of this._waiters) waiter.reject(error);
    this._waiters = [];
  }

  get isAlive() {
    return !this._deadError && this.child.exitCode === null && !this.child.killed;
  }

  _onData(chunk) {
    this._buf = Buffer.concat([this._buf, chunk]);
    while (true) {
      const headerEnd = this._buf.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = this._buf.subarray(0, headerEnd).toString('utf8');
      const match = /Content-Length:\s*(\d+)/i.exec(header);
      if (!match) {
        this._buf = this._buf.subarray(headerEnd + 4);
        continue;
      }
      const len = Number(match[1]);
      const bodyStart = headerEnd + 4;
      if (this._buf.length < bodyStart + len) return;
      const body = this._buf.subarray(bodyStart, bodyStart + len).toString('utf8');
      this._buf = this._buf.subarray(bodyStart + len);
      const waiter = this._waiters.shift();
      if (waiter) {
        try {
          waiter.resolve(JSON.parse(body));
        } catch (e) {
          waiter.reject(e);
        }
      }
    }
  }

  _writeFrame(message) {
    if (this._deadError) throw this._deadError;
    const body = JSON.stringify(message);
    const frame = `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`;
    this.child.stdin.write(frame, (error) => {
      if (error) this._markDead(error);
    });
  }

  /** @param {object} message */
  request(message) {
    const run = () =>
      new Promise((resolve, reject) => {
        if (this._deadError) {
          reject(this._deadError);
          return;
        }
        this._waiters.push({ resolve, reject });
        try {
          this._writeFrame(message);
        } catch (error) {
          this._waiters.pop();
          reject(error);
        }
      });
    const p = this._chain.then(run, run);
    this._chain = p.then(
      () => undefined,
      () => undefined,
    );
    return p;
  }

  /** Fire-and-forget notification (no response expected). */
  notify(message) {
    const run = () => {
      this._writeFrame(message);
    };
    const promise = this._chain.then(run, run);
    this._chain = promise.then(
      () => undefined,
      () => undefined,
    );
    return promise;
  }

  close() {
    try {
      this.child.stdin.end();
    } catch {
      /* ignore */
    }
    this.child.kill('SIGTERM');
  }
}
