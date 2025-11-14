#!/bin/bash

echo "=== MCP Diagnostic Check ==="
echo ""

echo "1. Checking MCP config file..."
if [ -f ~/.agentic-flow/mcp-config.json ]; then
  echo "✅ Config exists at ~/.agentic-flow/mcp-config.json"
  echo ""
  echo "Contents:"
  cat ~/.agentic-flow/mcp-config.json | jq .
else
  echo "❌ No config file found"
fi

echo ""
echo "2. Testing Brave MCP server startup..."
echo ""

# Start MCP server in background
npx -y @brave/brave-search-mcp-server > /tmp/mcp-test.log 2>&1 &
MCP_PID=$!

sleep 3

if ps -p $MCP_PID > /dev/null 2>&1; then
  echo "✅ Brave MCP server started (PID: $MCP_PID)"
  kill $MCP_PID 2>/dev/null
  wait $MCP_PID 2>/dev/null
else
  echo "❌ Brave MCP server failed to start"
  echo "Error log:"
  cat /tmp/mcp-test.log
fi

echo ""
echo "3. Checking environment variables..."
echo "BRAVE_API_KEY: ${BRAVE_API_KEY:+SET (hidden)}"
echo "ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:+SET (hidden)}"
echo "USE_GEMINI: $USE_GEMINI"
echo "PROVIDER: $PROVIDER"

echo ""
echo "4. Testing agentic-flow MCP loading..."
echo ""

# Capture loading messages
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-test}"
export USE_GEMINI=false
export PROVIDER=anthropic

npx agentic-flow --agent researcher --task "test" --provider anthropic 2>&1 | grep -i "loaded mcp\|brave\|mcp server" | head -10

echo ""
echo "=== Diagnosis Complete ==="
