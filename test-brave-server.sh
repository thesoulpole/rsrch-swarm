#!/bin/bash

echo "=== Testing Brave MCP Server Startup ==="
echo ""

echo "1. Testing direct server startup with verbose output..."
echo ""

# Set environment variable
export BRAVE_API_KEY="BSAhaSuk582CZNntJ7Q2mjQo9Cu7M6w"

# Try to start the server and capture ALL output
echo "Starting server..."
npx -y @brave/brave-search-mcp-server 2>&1 &
PID=$!

echo "Server PID: $PID"
echo "Waiting 5 seconds..."
sleep 5

if ps -p $PID > /dev/null 2>&1; then
  echo "✅ Server is running!"

  # Try to send it a test request
  echo ""
  echo "2. Sending test request..."
  echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | nc -w 1 localhost 3000 2>&1 || echo "Note: Server uses stdio, not TCP"

  # Kill it
  kill $PID 2>/dev/null
  echo "Server stopped"
else
  echo "❌ Server died or never started"
  echo ""
  echo "Checking npm cache..."
  npm list -g @brave/brave-search-mcp-server 2>&1 | head -5
fi

echo ""
echo "3. Checking if package exists..."
npm view @brave/brave-search-mcp-server version 2>&1

echo ""
echo "4. Testing with stdin/stdout (actual MCP protocol)..."
echo ""

# MCP servers communicate via stdio, not TCP
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0","capabilities":{}},"id":1}
{"jsonrpc":"2.0","method":"tools/list","id":2}' | BRAVE_API_KEY="BSAhaSuk582CZNntJ7Q2mjQo9Cu7M6w" npx -y @brave/brave-search-mcp-server 2>&1 | head -20

echo ""
echo "=== Test Complete ==="
