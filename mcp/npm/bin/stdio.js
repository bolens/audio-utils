#!/usr/bin/env node
/**
 * audio-utils-mcp — spawn the dep-free Bash MCP server on stdio (Cursor-friendly).
 */
import { spawnBashMcp } from '../lib/bash.js';

const child = spawnBashMcp({ stdio: 'inherit' });
child.on('exit', (code, signal) => {
  if (signal) process.exit(1);
  process.exit(code ?? 0);
});
process.on('SIGINT', () => child.kill('SIGINT'));
process.on('SIGTERM', () => child.kill('SIGTERM'));
