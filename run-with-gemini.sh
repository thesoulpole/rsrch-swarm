#!/bin/bash
# This script modifies no_proxy to allow Gemini API through the proxy

echo "🔧 Fixing no_proxy for Gemini API access..."

# Remove Google domains from no_proxy
export no_proxy="localhost,127.0.0.1,169.254.169.254,metadata.google.internal,*.svc.cluster.local,*.local"
export NO_PROXY="$no_proxy"
export GLOBAL_AGENT_NO_PROXY="$no_proxy"

# Force Gemini provider
export PROVIDER=gemini
export USE_GEMINI=true

echo "✅ Environment configured for Gemini:"
echo "   - Removed *.googleapis.com from no_proxy"
echo "   - Google APIs will now route through proxy"
echo "   - Provider set to: gemini"
echo ""

# Run research-swarm with all arguments passed through
npx research-swarm "$@"
