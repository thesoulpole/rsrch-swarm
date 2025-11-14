#!/usr/bin/env node
/**
 * Test if Brave MCP server can start and respond
 */

import { spawn } from 'child_process';

console.log('Testing Brave Search MCP Server...\n');

const server = spawn('npx', ['-y', '@brave/brave-search-mcp-server'], {
  env: {
    ...process.env,
    BRAVE_API_KEY: 'BSAhaSuk582CZNntJ7Q2mjQo9Cu7M6w'
  },
  stdio: ['pipe', 'pipe', 'pipe']
});

let output = '';
let errorOutput = '';

server.stdout.on('data', (data) => {
  output += data.toString();
  console.log('[STDOUT]:', data.toString());
});

server.stderr.on('data', (data) => {
  errorOutput += data.toString();
  console.error('[STDERR]:', data.toString());
});

server.on('error', (err) => {
  console.error('❌ Failed to start:', err);
  process.exit(1);
});

// Send a test request after 3 seconds
setTimeout(() => {
  console.log('\n📤 Sending test request...\n');

  const request = {
    jsonrpc: '2.0',
    method: 'tools/list',
    id: 1
  };

  server.stdin.write(JSON.stringify(request) + '\n');

  // Wait for response
  setTimeout(() => {
    console.log('\n✅ Server appears to be running');
    console.log('Output:', output);
    console.log('Errors:', errorOutput);
    server.kill();
    process.exit(0);
  }, 2000);
}, 3000);

setTimeout(() => {
  console.log('\n⏱️  Timeout - server took too long');
  server.kill();
  process.exit(1);
}, 10000);
