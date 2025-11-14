#!/bin/bash
# MCP Server Setup Script for agentic-flow

echo "🔧 MCP Server Configuration Setup"
echo "=================================="
echo ""

# Check current API keys
echo "📋 Checking API Keys..."
echo ""

HAS_PROVIDER=false

if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "✅ ANTHROPIC_API_KEY is set"
    HAS_PROVIDER=true
elif [ -n "$GOOGLE_GEMINI_API_KEY" ]; then
    echo "✅ GOOGLE_GEMINI_API_KEY is set"
    HAS_PROVIDER=true
elif [ -n "$OPENROUTER_API_KEY" ]; then
    echo "✅ OPENROUTER_API_KEY is set"
    HAS_PROVIDER=true
else
    echo "❌ No provider API key found!"
    echo ""
    echo "You need to set at least ONE of these:"
    echo "  export ANTHROPIC_API_KEY='sk-ant-...'"
    echo "  export GOOGLE_GEMINI_API_KEY='...'"
    echo "  export OPENROUTER_API_KEY='...'"
    echo ""
    echo "Get API keys from:"
    echo "  - Anthropic: https://console.anthropic.com/"
    echo "  - Gemini: https://ai.google.dev/"
    echo "  - OpenRouter: https://openrouter.ai/"
    echo ""
fi

# Check Brave API key
if [ -n "$BRAVE_API_KEY" ]; then
    echo "✅ BRAVE_API_KEY is set"
    HAS_BRAVE=true
else
    echo "⚠️  BRAVE_API_KEY not set (web search will be limited)"
    echo "   Get free API key: https://brave.com/search/api/"
    HAS_BRAVE=false
fi

echo ""
echo "📁 MCP Configuration Files:"
echo ""

# Show current config
if [ -f ~/.agentic-flow/mcp-config.json ]; then
    echo "Current: ~/.agentic-flow/mcp-config.json"
    cat ~/.agentic-flow/mcp-config.json
else
    echo "❌ No config file found"
fi

echo ""
echo "=================================="

if [ "$HAS_PROVIDER" = true ]; then
    echo "✅ Setup complete! You can now use:"
    echo ""
    if [ "$HAS_BRAVE" = true ]; then
        echo "   # Enable Brave search:"
        echo "   cp ~/.agentic-flow/mcp-config-with-brave.json ~/.agentic-flow/mcp-config.json"
        echo ""
    fi
    echo "   # Test the researcher:"
    echo "   npx agentic-flow@latest --agent researcher --task 'research AI trends' --provider anthropic"
    echo ""
else
    echo "⚠️  Please set API keys first, then run this script again"
fi
