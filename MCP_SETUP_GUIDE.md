# MCP Server Setup Guide for agentic-flow

## Problem Summary

When running `npx agentic-flow@latest --agent researcher`, the agent has **no web access** because:

1. ❌ The MCP configuration file didn't exist: `~/.agentic-flow/mcp-config.json`
2. ❌ No API keys were set in the environment
3. ❌ MCP servers (like Brave Search) weren't being loaded

## Solution

### Quick Setup (3 steps)

1. **Set Provider API Key** (choose one):
```bash
# Option A: Anthropic (most reliable)
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

# Option B: Google Gemini (free tier)
export GOOGLE_GEMINI_API_KEY="your-key-here"

# Option C: OpenRouter (multi-model)
export OPENROUTER_API_KEY="your-key-here"
```

2. **Set Brave Search API Key** (optional, for web search):
```bash
export BRAVE_API_KEY="your-brave-key-here"
```

Get a FREE Brave Search API key: https://brave.com/search/api/
- 1000 searches/month free tier
- No credit card required

3. **Enable Brave in MCP config**:
```bash
# Copy the config with Brave enabled
cp ~/.agentic-flow/mcp-config-with-brave.json ~/.agentic-flow/mcp-config.json
```

### Test It Works

```bash
# Test basic web fetch (no Brave key needed)
npx agentic-flow@latest --agent researcher \
  --task "fetch and summarize example.com" \
  --provider anthropic

# Test web search (requires Brave API key)
npx agentic-flow@latest --agent researcher \
  --task "research the latest AI developments in 2024" \
  --provider anthropic
```

## MCP Configuration Files

### Location
`~/.agentic-flow/mcp-config.json`

### Current Configurations

**Option 1: Basic (fetch only, no API key needed)**
```json
{
  "servers": {
    "fetch": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
```

**Option 2: With Brave Search (requires API key)**
```json
{
  "servers": {
    "brave-search": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    },
    "fetch": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
```

**Option 3: Advanced (all web tools)**
```json
{
  "servers": {
    "brave-search": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    },
    "fetch": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "puppeteer": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    }
  }
}
```

## Available MCP Servers

### Web Access
- **fetch** - Fetch web pages (no API key)
- **brave-search** - Web search (requires Brave API key)
- **puppeteer** - Browser automation for JS-heavy sites

### Other Useful Servers
- **filesystem** - Read/write files
- **sqlite** - Database operations
- **github** - GitHub API access (requires token)
- **google-maps** - Maps and location data (requires API key)

## Troubleshooting

### "No web access" / Agent can't search the web
```bash
# Check API keys
./setup-mcp.sh

# Verify MCP config exists
cat ~/.agentic-flow/mcp-config.json

# Enable Brave search
cp ~/.agentic-flow/mcp-config-with-brave.json ~/.agentic-flow/mcp-config.json
```

### "ANTHROPIC_API_KEY is required"
```bash
# Set your Anthropic API key
export ANTHROPIC_API_KEY="sk-ant-xxxxx"

# OR use a different provider
npx agentic-flow@latest --agent researcher --task "test" --provider gemini
```

### MCP server not loading
```bash
# Check if config file exists
ls -la ~/.agentic-flow/

# Verify JSON is valid
cat ~/.agentic-flow/mcp-config.json | python3 -m json.tool

# Check environment variables are set
echo $BRAVE_API_KEY
echo $ANTHROPIC_API_KEY
```

### Debug MCP loading
```bash
# Enable verbose logging
DEBUG=* npx agentic-flow@latest --agent researcher --task "test" --verbose
```

## Why Debug Logging Doesn't Show

**The code you edited is NOT being executed!**

When you run `npx agentic-flow@latest`:
1. It downloads the **published npm package** from the registry
2. Caches it in `~/.npm/_npx/`
3. Runs the **published code**, NOT local files

To see debug output from custom code, you need to:
1. Clone the agentic-flow repository
2. Make your changes
3. Build it: `npm run build`
4. Link it locally: `npm link`
5. Use it: `npx agentic-flow` (will use linked version)

## API Key Resources

### Free Options
- **Gemini**: https://ai.google.dev/ (generous free tier)
- **Brave Search**: https://brave.com/search/api/ (1000 searches/month)

### Paid Options
- **Anthropic Claude**: https://console.anthropic.com/
- **OpenRouter**: https://openrouter.ai/ (pay-per-use, many models)

## Next Steps

1. Run the setup checker:
```bash
./setup-mcp.sh
```

2. Set your API keys

3. Test the researcher:
```bash
npx agentic-flow@latest --agent researcher \
  --task "research the latest developments in AI agents" \
  --provider anthropic
```

4. Check if Brave search is working (you should see web search queries in output)

## Files Created

- `~/.agentic-flow/mcp-config.json` - Current MCP configuration
- `~/.agentic-flow/mcp-config-with-brave.json` - Config template with Brave enabled
- `./setup-mcp.sh` - Setup checker script
- `./MCP_SETUP_GUIDE.md` - This guide

---

**Last updated**: 2025-11-14
**Created by**: Claude Code Analysis
