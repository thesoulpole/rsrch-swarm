# Research Swarm Analysis Project

This repository contains comprehensive research and analysis of agentic coding frameworks and the debugging of research-swarm/agentic-flow issues.

## Files

### Research Documents
- **AGENTIC_CODING_FRAMEWORKS_RESEARCH.md** - Comprehensive research covering 30+ agentic coding frameworks that spawn and orchestrate agents for end-to-end coding tasks

### Analysis & Fixes  
- **RESEARCH_SWARM_ANALYSIS.md** - Deep technical analysis of why research-swarm is failing, including code paths, architecture diagrams, and root cause identification
- **HOW_TO_FIX_RESEARCH_SWARM.md** - Quick reference guide with verified working solutions and workarounds

## Quick Fix for research-swarm

```bash
USE_GEMINI=false PROVIDER=anthropic npx research-swarm research researcher "your task"
```

## Summary of Findings

### Problem
research-swarm and agentic-flow fail with "fetch failed" errors because:
1. Provider selection bug incorrectly chooses Gemini proxy despite `--provider anthropic` 
2. Gemini proxy attempts to connect to Google's API but network is blocked

### Solution  
Set environment variables to force direct Anthropic API usage:
- `USE_GEMINI=false`
- `PROVIDER=anthropic`

### Impact
- Affects research-swarm v1.2.2
- Affects agentic-flow v1.10.2  
- May affect claude-flow v2.7.35-alpha

See individual documents for detailed information.
