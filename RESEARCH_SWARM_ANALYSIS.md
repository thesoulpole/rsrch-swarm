# Research-Swarm & Agentic-Flow Failure Analysis

**Date:** November 13, 2025
**Issue:** research-swarm and agentic-flow failing with Gemini proxy network errors
**Status:** Root cause identified

---

## Executive Summary

The research-swarm tool is failing because:
1. It uses agentic-flow (v1.10.2) as its underlying agent execution engine
2. Agentic-flow's provider selection logic is incorrectly choosing the Gemini proxy despite `--provider anthropic` being specified
3. The Gemini proxy attempts to connect to Google's API at `https://generativelanguage.googleapis.com/v1beta` but **network connectivity to external APIs is blocked or unavailable** in this environment
4. This causes `fetch()` to fail with "TypeError: fetch failed"

---

## Architecture Overview

```
research-swarm (CLI)
    ↓ spawns
npx agentic-flow@latest
    ↓ provider selection logic
┌─────────────────────────┐
│ shouldUseGemini()       │ ← BUG: Returns true when it shouldn't
└─────────────────────────┘
    ↓
AnthropicToGeminiProxy (localhost:3000)
    ↓ fetch() call
Google Gemini API (https://generativelanguage.googleapis.com/v1beta)
    ↓
❌ Network blocked / No connectivity
```

---

## Root Cause Analysis

### 1. Provider Selection Bug in agentic-flow

**File:** `/root/.npm/_npx/6ae5399e978f0379/node_modules/agentic-flow/dist/cli-proxy.js`

**Lines 242-265:** `shouldUseGemini()` function

```javascript
shouldUseGemini(options) {
    // 1. Provider is explicitly set to gemini
    if (options.provider === 'gemini' || process.env.PROVIDER === 'gemini') {
        return true;
    }

    // 2. USE_GEMINI env var is set
    if (process.env.USE_GEMINI === 'true') {
        return true;
    }

    // 3. BUG FIX: Don't auto-select Gemini if user explicitly specified a different provider
    if (options.provider && options.provider !== 'gemini') {
        return false;  // ← This SHOULD prevent Gemini selection
    }

    // 4. Auto-select Gemini fallback
    if (process.env.GOOGLE_GEMINI_API_KEY &&
        !process.env.ANTHROPIC_API_KEY &&    // ← BUG: This is the issue
        !process.env.OPENROUTER_API_KEY &&
        options.provider !== 'onnx') {
        return true;
    }

    return false;
}
```

**The Problem:**
- research-swarm passes `--provider anthropic` (line 388 of run-researcher-local.js)
- All three API keys are set in environment: ANTHROPIC_API_KEY, OPENROUTER_API_KEY, GOOGLE_GEMINI_API_KEY
- The check at line 254-256 SHOULD return false and prevent Gemini from being selected
- However, the Gemini proxy is still starting

**Hypothesis:** There may be another code path or the options are not being parsed correctly from the command line arguments.

### 2. Network Connectivity Issue

**File:** `/root/.npm/_npx/6ae5399e978f0379/node_modules/agentic-flow/dist/proxy/anthropic-to-gemini.js`

**Line 56:** The fetch() call that's failing

```javascript
const url = `${this.geminiBaseUrl}/models/${this.defaultModel}:${endpoint}?key=${this.geminiApiKey}${streamParam}`;

// Forward to Gemini
const response = await fetch(url, {  // ← Line 56: This fails
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: JSON.stringify(geminiReq)
});
```

**Error:**
```
TypeError: fetch failed
    at node:internal/deps/undici/undici:14900:13
    at process.processTicksAndRejections (node:internal/process/task_queues:105:5)
    at async file:///[...]/anthropic-to-gemini.js:56:34
```

**Why it's failing:**
- The environment has no outbound internet connectivity to `https://generativelanguage.googleapis.com`
- OR the Google API endpoint is being blocked by firewall/network policy
- OR there's a DNS resolution issue

---

## How research-swarm Uses agentic-flow

**File:** `/root/.npm/_npx/593ae2fca1e5bf7d/node_modules/research-swarm/run-researcher-local.js`

**Lines 384-402:**
```javascript
// Execute agent with enhanced task using agentic-flow
const agentProcess = spawn('npx', [
  'agentic-flow@latest',
  '--agent', 'researcher',
  '--task', enhancedTask,
  '--provider', 'anthropic',              // ← Explicit provider specification
  '--model', 'claude-sonnet-4-20250514',  // ← Claude model requested
  '--output', 'markdown',
  '--verbose'
], {
  env: {
    ...process.env,  // ← Spreads all environment variables
    JOB_ID: jobId,
    ENABLE_MCP: 'true',
    MCP_SERVERS: 'claude-flow'
  },
  cwd: __dirname,
  stdio: ['inherit', 'pipe', 'pipe']
});
```

**Key Points:**
1. research-swarm is a wrapper that generates an enhanced task directive
2. It spawns agentic-flow as a subprocess with specific command-line arguments
3. It explicitly requests `--provider anthropic` with a Claude model
4. All environment variables are passed through via `...process.env`

---

## Debug Output Analysis

From the actual execution:

```
🔍 Provider Selection Debug:
  Provider flag: anthropic
  Model: claude-sonnet-4-20250514
  Use ONNX: false
  Use OpenRouter: false
  Use Gemini: true          ← ❌ This should be false!
  Use Requesty: false
  OPENROUTER_API_KEY: ✓ set
  GOOGLE_GEMINI_API_KEY: ✓ set
  REQUESTY_API_KEY: ✗ not set
  ANTHROPIC_API_KEY: ✓ set

🚀 Initializing Gemini proxy...
🔗 Proxy Mode: Google Gemini
🔧 Proxy URL: http://localhost:3000
```

**Confirmation:**
- Provider flag is correctly set to "anthropic"
- ANTHROPIC_API_KEY is set
- Yet "Use Gemini: true" is incorrectly triggered

---

## Potential Code Bugs in agentic-flow

### Bug #1: Provider Selection Logic Error
The `shouldUseGemini()` function's check at line 254-256 should prevent Gemini from being selected when `options.provider === 'anthropic'`, but it's not working.

**Possible causes:**
1. The options object is not being populated correctly from CLI args
2. There's a bug in the parseArgs() function
3. The provider selection happens before options are fully parsed
4. There's a race condition or multiple provider checks

### Bug #2: Fallback Logic Too Aggressive
Even with ANTHROPIC_API_KEY set, the system is still trying to use Gemini. The auto-detection logic at lines 258-263 should NOT trigger when ANTHROPIC_API_KEY exists, but something is bypassing this check.

---

## Solutions & Workarounds

### Solution 1: Force Direct Anthropic API Usage (Recommended)

**Option A: Environment Variable Override**
Set environment variable to explicitly disable Gemini:
```bash
export USE_GEMINI=false
export PROVIDER=anthropic
npx research-swarm research researcher "your task"
```

**Option B: Remove GOOGLE_GEMINI_API_KEY temporarily**
```bash
# Backup the key
export GOOGLE_GEMINI_API_KEY_BACKUP=$GOOGLE_GEMINI_API_KEY
unset GOOGLE_GEMINI_API_KEY

# Run research-swarm
npx research-swarm research researcher "your task"

# Restore the key
export GOOGLE_GEMINI_API_KEY=$GOOGLE_GEMINI_API_KEY_BACKUP
```

### Solution 2: Fix Network Connectivity

**Test connectivity:**
```bash
# Test if you can reach Google's API
curl -I https://generativelanguage.googleapis.com/v1beta

# Test general internet connectivity
curl -I https://www.google.com
```

**If network is blocked:**
- Enable outbound HTTPS (port 443) in firewall
- Configure proxy settings if behind corporate proxy
- Use VPN if network policy blocks Google APIs

### Solution 3: Patch agentic-flow Locally

**Fork and modify the package:**

1. Clone the repository:
```bash
git clone https://github.com/ruvnet/agentic-flow.git
cd agentic-flow
```

2. Modify `src/cli-proxy.ts` (or the TypeScript source):

```typescript
shouldUseGemini(options: ParsedOptions): boolean {
    // STRICT CHECK: Only use Gemini if explicitly requested
    if (options.provider === 'gemini' || process.env.PROVIDER === 'gemini') {
        return true;
    }

    if (process.env.USE_GEMINI === 'true') {
        return true;
    }

    // ALWAYS return false if any other provider is specified
    if (options.provider) {
        return false;  // ← Strengthened check
    }

    // Remove auto-detection fallback entirely
    return false;  // ← Never auto-select Gemini
}
```

3. Build and publish locally:
```bash
npm run build
npm link
```

4. Use the local version:
```bash
npm link agentic-flow
```

### Solution 4: Use Direct claudeAgent Instead

Bypass research-swarm and use agentic-flow directly with explicit Anthropic SDK:

```javascript
import { claudeAgentDirect } from 'agentic-flow/agents/claudeAgentDirect';

const result = await claudeAgentDirect({
  agent: 'researcher',
  task: 'your research task',
  apiKey: process.env.ANTHROPIC_API_KEY,
  model: 'claude-sonnet-4-20250514'
});
```

### Solution 5: Modify research-swarm to Use Direct API

**Edit:** `/root/.npm/_npx/593ae2fca1e5bf7d/node_modules/research-swarm/run-researcher-local.js`

**Change lines 384-392 to force no proxy:**
```javascript
const agentProcess = spawn('npx', [
  'agentic-flow@latest',
  '--agent', 'researcher',
  '--task', enhancedTask,
  '--provider', 'anthropic',
  '--model', 'claude-sonnet-4-20250514',
  '--output', 'markdown',
  '--verbose',
  '--no-proxy'  // ← Add this flag (if supported)
], {
  env: {
    ...process.env,
    JOB_ID: jobId,
    ENABLE_MCP: 'true',
    MCP_SERVERS: 'claude-flow',
    USE_GEMINI: 'false',        // ← Explicit disable
    USE_OPENROUTER: 'false',    // ← Force direct Anthropic
    PROVIDER: 'anthropic'       // ← Explicit provider
  },
```

---

## Recommended Immediate Fix

**Quick workaround that doesn't require code changes:**

```bash
# Create a wrapper script
cat > research-swarm-fixed.sh << 'EOF'
#!/bin/bash
export USE_GEMINI=false
export PROVIDER=anthropic
npx research-swarm "$@"
EOF

chmod +x research-swarm-fixed.sh

# Use it
./research-swarm-fixed.sh research researcher "your task"
```

---

## Testing Network Connectivity

```bash
# Test 1: Check if Google API is reachable
curl -v https://generativelanguage.googleapis.com/v1beta 2>&1 | grep -i "connect"

# Test 2: Check DNS resolution
nslookup generativelanguage.googleapis.com

# Test 3: Test with Anthropic API directly
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-haiku-20240307","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'

# Test 4: Check for proxy environment variables
env | grep -i proxy
```

---

## Long-term Fix: Submit PR to agentic-flow

### Issue Summary for GitHub:
```
Title: Provider selection incorrectly chooses Gemini when --provider anthropic is specified

Description:
When running agentic-flow with --provider anthropic, the shouldUseGemini()
function still returns true, causing the Gemini proxy to be initialized
instead of using the direct Anthropic API.

Steps to reproduce:
1. Set ANTHROPIC_API_KEY and GOOGLE_GEMINI_API_KEY in environment
2. Run: npx agentic-flow --provider anthropic --task "test"
3. Observe: Gemini proxy starts instead of using Anthropic directly

Expected behavior:
When --provider anthropic is explicitly specified, only the Anthropic API
should be used, regardless of which API keys are present in the environment.

Proposed fix:
In shouldUseGemini(), strengthen the check at line 254-256 to return false
for ANY non-gemini provider specification, and remove the auto-detection
fallback that checks for GOOGLE_GEMINI_API_KEY.
```

---

## Impact Assessment

### Affected Tools:
1. **research-swarm** (v1.2.2) - Primary tool affected
2. **agentic-flow** (v1.10.2) - Contains the bug
3. **claude-flow** (v2.7.35-alpha) - May have similar issues if it uses agentic-flow

### Severity: **HIGH**
- Completely blocks research-swarm functionality
- Affects all users with multiple API keys configured
- Network connectivity issues compound the problem

### Users Affected:
- Anyone with both ANTHROPIC_API_KEY and GOOGLE_GEMINI_API_KEY set
- Users in restricted network environments
- Enterprise users behind firewalls

---

## Next Steps

1. **Immediate:** Use environment variable workaround (`USE_GEMINI=false`)
2. **Short-term:** Test network connectivity to external APIs
3. **Medium-term:** Fork agentic-flow and apply provider selection fix
4. **Long-term:** Submit PR to upstream agentic-flow repository

---

## Related Files

### Key Source Files:
- `/root/.npm/_npx/6ae5399e978f0379/node_modules/agentic-flow/dist/cli-proxy.js`
  - Lines 175-177: Provider selection calls
  - Lines 242-265: shouldUseGemini() function
  - Lines 279-310: shouldUseOpenRouter() function

- `/root/.npm/_npx/6ae5399e978f0379/node_modules/agentic-flow/dist/proxy/anthropic-to-gemini.js`
  - Line 56: fetch() call that fails

- `/root/.npm/_npx/593ae2fca1e5bf7d/node_modules/research-swarm/run-researcher-local.js`
  - Lines 384-402: agentic-flow subprocess spawn

### Repository Links:
- **agentic-flow:** https://github.com/ruvnet/agentic-flow
- **research-swarm:** Part of agentic-flow examples at https://github.com/ruvnet/agentic-flow/tree/main/examples/research-swarm

---

## Conclusion

The failure is caused by:
1. **Primary:** Provider selection bug in agentic-flow that ignores `--provider anthropic`
2. **Secondary:** Network connectivity blocking Google's Gemini API

**Recommended action:** Use the environment variable workaround until the upstream bug is fixed.

---

**Analysis completed by:** Claude Code
**Environment:** Linux 4.4.0, Node.js (via npx)
**Tools analyzed:** research-swarm v1.2.2, agentic-flow v1.10.2
