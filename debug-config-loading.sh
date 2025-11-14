#!/bin/bash

echo "=== Debugging Why Brave MCP Isn't Loading ==="
echo ""

echo "1. Check config file location and permissions..."
CONFIG_FILE="$HOME/.agentic-flow/mcp-config.json"
echo "Config path: $CONFIG_FILE"
echo "Home dir: $HOME"

if [ -f "$CONFIG_FILE" ]; then
  echo "✅ Config file exists"
  ls -la "$CONFIG_FILE"
  echo ""
  echo "Config contents:"
  cat "$CONFIG_FILE"
else
  echo "❌ Config file NOT found at $CONFIG_FILE"
fi

echo ""
echo "2. Test if node can read the config..."
node -e "
const fs = require('fs');
const os = require('os');
const path = require('path');

const configPath = path.join(os.homedir(), '.agentic-flow', 'mcp-config.json');
console.log('Node homedir:', os.homedir());
console.log('Config path:', configPath);
console.log('File exists:', fs.existsSync(configPath));

if (fs.existsSync(configPath)) {
  try {
    const content = fs.readFileSync(configPath, 'utf-8');
    const config = JSON.parse(content);
    console.log('✅ Config parsed successfully');
    console.log('Servers found:', Object.keys(config.servers || {}));

    for (const [name, server] of Object.entries(config.servers || {})) {
      console.log(\`  - \${name}: enabled=\${server.enabled}\`);
    }
  } catch (err) {
    console.error('❌ Error reading config:', err.message);
  }
} else {
  console.log('❌ Config file not found');
}
"

echo ""
echo "3. Check if agentic-flow can see the config..."
echo "Running agentic-flow with debug output..."

export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-test}"
npx agentic-flow --agent researcher --task "test" --provider anthropic 2>&1 | head -100 | grep -A 5 -B 5 -E "config|mcp-config|Loaded MCP|brave"

echo ""
echo "=== Diagnosis Complete ==="
