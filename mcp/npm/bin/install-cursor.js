#!/usr/bin/env node
/**
 * audio-utils-mcp-install-cursor — wrap mcp/install-cursor.sh
 */
import { spawn } from 'node:child_process';
import { installCursorScriptPath } from '../lib/bash.js';

const args = process.argv.slice(2);
const child = spawn(installCursorScriptPath(), args, { stdio: 'inherit' });
child.on('exit', (code, signal) => {
  if (signal) process.exit(1);
  process.exit(code ?? 0);
});
