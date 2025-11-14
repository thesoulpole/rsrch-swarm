# Research-Swarm Local Setup Guide

## Problem
The `researcher` agent is configured for codebase analysis ONLY. It doesn't use web search even though Brave MCP is configured.

## Solution: Use Direct agentic-flow with Custom Prompt

### Step 1: Set Up Brave MCP (Already Done!)

```bash
# Brave MCP is already configured at: ~/.agentic-flow/mcp-config.json
# Your API key: BSAhaSuk582CZNntJ7Q2mjQo9Cu7M6w
```

### Step 2: Set Environment Variables

```bash
export ANTHROPIC_API_KEY="your-anthropic-key-here"
export USE_GEMINI=false
export PROVIDER=anthropic
```

### Step 3: Run Web Research with Explicit Instructions

Instead of using `research-swarm`, use `agentic-flow` directly with a web-research task:

```bash
npx agentic-flow \
  --agent researcher \
  --task "Use brave_web_search MCP tool to research cloud computing trends. Search for: 1) latest cloud trends 2025, 2) serverless computing adoption, 3) multi-cloud strategies. Compile findings with citations." \
  --provider anthropic \
  --model claude-sonnet-4-20250514 \
  --verbose
```

### Step 4: Create a Web Research Wrapper Script

```bash
cat > ~/web-research << 'EOF'
#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ~/web-research \"your research topic\""
  exit 1
fi

TOPIC="$1"

export USE_GEMINI=false
export PROVIDER=anthropic

npx agentic-flow \
  --agent researcher \
  --task "You have access to brave_web_search, brave_news_search, and brave_video_search MCP tools. Use them to research: ${TOPIC}.

Instructions:
1. Use brave_web_search to find current information
2. Use brave_news_search for recent developments
3. Compile findings with proper citations
4. Include URLs for all sources
5. Summarize key trends and insights

Research topic: ${TOPIC}" \
  --provider anthropic \
  --model claude-sonnet-4-20250514 \
  --output markdown \
  --verbose
EOF

chmod +x ~/web-research
```

### Step 5: Use the Wrapper

```bash
~/web-research "Analyze cloud computing trends in 2025"
```

## Alternative: Create Custom Web Research Agent

Create a file at `~/.agentic-flow/agents/web-researcher.md`:

```markdown
---
name: web-researcher
type: analyst
description: Web research specialist with internet access
capabilities:
  - web_search
  - news_research
  - information_synthesis
priority: high
---

# Web Research Specialist

You are a web research specialist with access to Brave Search MCP tools.

## Available Tools

You have access to these MCP tools:
- **brave_web_search**: General web search
- **brave_local_search**: Local business search
- **brave_news_search**: News and current events
- **brave_video_search**: Video content search
- **brave_image_search**: Image search
- **brave_summarizer**: AI-powered summarization

## Research Methodology

1. **Start with brave_web_search** for general information
2. **Use brave_news_search** for recent developments
3. **Cross-reference** multiple sources
4. **Always cite** sources with URLs
5. **Synthesize** findings into coherent insights

## Output Format

```markdown
# Research: [Topic]

## Summary
[2-3 sentence overview]

## Key Findings
1. **Finding 1**
   - Source: [Title](URL)
   - Details: ...

2. **Finding 2**
   - Source: [Title](URL)
   - Details: ...

## Trends and Patterns
- Pattern 1...
- Pattern 2...

## Sources
- [Source 1](URL)
- [Source 2](URL)
```

## Best Practices

1. **Always use MCP tools** - Don't rely on training data
2. **Verify information** across multiple sources
3. **Include citations** for credibility
4. **Stay current** - prefer recent sources
5. **Be thorough** - search multiple queries for comprehensive coverage
```

Then use it:

```bash
npx agentic-flow \
  --agent web-researcher \
  --task "Research cloud computing trends" \
  --provider anthropic \
  --verbose
```

## Troubleshooting

### Agent still doesn't use web search

The agent may not realize it has the tools. Add explicit instructions:

```bash
npx agentic-flow \
  --agent researcher \
  --task "IMPORTANT: You have brave_web_search MCP tool available. Use it to search the web for: [your topic]. Do NOT say you don't have web access." \
  --provider anthropic \
  --verbose
```

### Check if MCP tools are loaded

Run with `--verbose` and look for:
```
[agentic-flow] Loaded MCP server: brave-search
```

### Verify Brave MCP is working

```bash
node /home/user/rsrch-swarm/test-brave-mcp.js
```

Should show: `✅ Server appears to be running`

## Summary

**The issue:** `research-swarm` uses the `researcher` agent which is designed for codebase analysis, not web research.

**The solution:**
1. Use `agentic-flow` directly
2. Give explicit instructions to use MCP tools
3. Or create a custom `web-researcher` agent

**Commands:**
```bash
# Quick web research
npx agentic-flow \
  --agent researcher \
  --task "Use brave_web_search to research: YOUR TOPIC. Include citations." \
  --provider anthropic \
  --verbose

# Or use the wrapper script
~/web-research "YOUR TOPIC"
```
