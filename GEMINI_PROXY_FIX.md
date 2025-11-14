# How to Fix Gemini API Connectivity in agentic-flow

## Root Cause Identified ✓

The Gemini proxy in agentic-flow **cannot reach Google's API** because:

### Primary Issue: Node.js fetch() Doesn't Respect Proxy Settings

**The Problem:**
- Your environment has `no_proxy` set to include `*.googleapis.com` and `*.google.com`
- This tells Node.js fetch() to bypass the proxy for Google APIs
- But direct connections are blocked in this Claude Code environment
- All connections MUST go through the Anthropic proxy at `http://...@21.0.0.61:15004`

**Evidence:**
```bash
# curl works (goes through proxy despite no_proxy)
$ curl https://generativelanguage.googleapis.com/v1beta/models
✓ Success (via proxy)

# Node.js fetch() fails (respects no_proxy, tries direct connection)
$ node -e "await fetch('https://generativelanguage.googleapis.com/v1beta/models')"
✗ TypeError: fetch failed
```

### Secondary Issue: API Authentication

Even if the proxy worked, the API call returns `403 Forbidden` without proper API key in the URL.

---

## Environment Details

**Proxy Configuration:**
```bash
https_proxy=http://container_...@21.0.0.61:15004
no_proxy=localhost,127.0.0.1,*.googleapis.com,*.google.com  ← The problem
```

**What happens:**
1. Node.js sees `*.googleapis.com` in `no_proxy`
2. Tries to connect directly to Google
3. Direct connection blocked → "fetch failed"

**What curl does:**
1. curl ignores or misinterprets the wildcard
2. Goes through the proxy anyway
3. ✓ Works

---

## Solution Options

### Option 1: Fix no_proxy in Environment (Best for You)

Remove Google domains from `no_proxy` so Node.js routes through the proxy:

```bash
# Create a wrapper script
cat > ~/research-swarm-gemini << 'EOF'
#!/bin/bash

# Fix no_proxy to allow Google APIs through proxy
export no_proxy="localhost,127.0.0.1,169.254.169.254,metadata.google.internal,*.svc.cluster.local,*.local"
export NO_PROXY="$no_proxy"
export GLOBAL_AGENT_NO_PROXY="$no_proxy"

# Force Gemini provider
export PROVIDER=gemini
export USE_GEMINI=true

# Run research-swarm
npx research-swarm "$@"
EOF

chmod +x ~/research-swarm-gemini

# Use it
~/research-swarm-gemini research researcher "your task"
```

### Option 2: Patch agentic-flow to Use Proxy-Aware Fetch

The agentic-flow code needs to use a fetch implementation that respects proxies.

**Current code** (`anthropic-to-gemini.js` line 56):
```javascript
const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(geminiReq)
});
```

**Fixed code** (needs proxy agent):
```javascript
import { ProxyAgent } from 'undici';
import https from 'https';
import http from 'http';

// Create proxy-aware agent
const proxyUrl = process.env.https_proxy || process.env.HTTPS_PROXY;
const HttpsProxyAgent = (await import('https-proxy-agent')).HttpsProxyAgent;
const agent = proxyUrl ? new HttpsProxyAgent(proxyUrl) : undefined;

// OR use axios which handles proxies automatically
import axios from 'axios';
const response = await axios.post(url, geminiReq, {
    headers: { 'Content-Type': 'application/json' }
});
```

### Option 3: Use Global Proxy Agent

Install and configure `global-agent` to make all fetch() calls proxy-aware:

```javascript
// At the top of anthropic-to-gemini.js
import { bootstrap } from 'global-agent';
bootstrap();
```

But this requires adding `global-agent` as a dependency to agentic-flow.

### Option 4: Keep Using Anthropic (Recommended)

Since Anthropic API works perfectly in your environment, just stick with:

```bash
export USE_GEMINI=false
export PROVIDER=anthropic
npx research-swarm research researcher "your task"
```

---

## Testing the Fix

If you modify `no_proxy` to allow Google through the proxy:

```bash
# Test 1: Verify no_proxy is fixed
echo $no_proxy | grep googleapis
# Should return nothing

# Test 2: Test with Node.js fetch
node -e "fetch('https://generativelanguage.googleapis.com/v1beta/models').then(r => console.log('Status:', r.status)).catch(e => console.log('Error:', e.message))"
# Should show a status code (likely 403 or 401 without API key)

# Test 3: Run research-swarm with Gemini
export PROVIDER=gemini
export USE_GEMINI=true
npx research-swarm research researcher "test" --depth 3 --time 5
# Should start without "fetch failed" errors
```

---

## Why This Environment is Special

You're running in **Claude Code Remote** which:
- Routes all traffic through an Anthropic proxy
- Blocks direct external connections
- Requires proxy authentication with JWT tokens
- Sets `no_proxy` to exclude certain domains (including Google APIs)

This is a security/monitoring feature, but it breaks tools that:
1. Respect `no_proxy` literally (Node.js fetch, undici)
2. Try to make direct connections when domains are in `no_proxy`

curl works because it has different `no_proxy` wildcard matching behavior.

---

## Recommended Approach for Using Gemini

### Short-term (Immediate):

**Just use Anthropic** - it works perfectly:
```bash
export USE_GEMINI=false
export PROVIDER=anthropic
```

### Medium-term (If you must use Gemini):

**Fix your environment's no_proxy:**
```bash
# Add to your shell profile (~/.bashrc or ~/.zshrc)
export no_proxy="localhost,127.0.0.1,169.254.169.254,metadata.google.internal,*.svc.cluster.local,*.local"
export NO_PROXY="$no_proxy"
export GLOBAL_AGENT_NO_PROXY="$no_proxy"
```

Then restart your shell or Claude Code session.

### Long-term (For agentic-flow maintainers):

**Fix the upstream code:**

1. Fork https://github.com/ruvnet/agentic-flow
2. Modify `src/proxy/anthropic-to-gemini.ts`
3. Replace `fetch()` with proxy-aware `axios` or add `https-proxy-agent`
4. Update dependencies in `package.json`:
   ```json
   "dependencies": {
     "axios": "^1.13.2",  // Already has this
     "https-proxy-agent": "^7.0.0"  // Add this
   }
   ```
5. Submit PR with title: "Fix Gemini proxy to respect https_proxy environment variable"

---

## Technical Deep Dive

### Why Node.js fetch() Doesn't Use Proxies by Default

Node.js's built-in `fetch()` (available since v18) uses `undici` internally, which:
- **Does** respect `no_proxy` environment variable
- **Doesn't** automatically use `https_proxy` for requests
- Requires explicit `dispatcher` configuration with `ProxyAgent`

Compare to:
- `axios`: Automatically uses `https_proxy` and respects `no_proxy`
- `node-fetch`: With `https-proxy-agent`, respects proxies
- `got`: Has built-in proxy support
- `curl`: Uses proxy by default, different wildcard matching for `no_proxy`

### The Correct Fix for anthropic-to-gemini.js

```javascript
import axios from 'axios';  // Already a dependency

export class AnthropicToGeminiProxy {
  // ...existing code...

  async forwardToGemini(url, geminiReq) {
    try {
      // axios automatically respects https_proxy and no_proxy
      const response = await axios.post(url, geminiReq, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 30000
      });

      return {
        ok: true,
        status: response.status,
        json: async () => response.data,
        text: async () => JSON.stringify(response.data)
      };
    } catch (error) {
      // Handle axios errors
      if (error.response) {
        return {
          ok: false,
          status: error.response.status,
          json: async () => error.response.data,
          text: async () => JSON.stringify(error.response.data)
        };
      }
      throw error;
    }
  }
}
```

---

## Summary

### The Core Issue:
Node.js `fetch()` in agentic-flow respects `no_proxy` and tries direct connections to Google, which fail in this environment.

### Quick Fix:
```bash
export USE_GEMINI=false PROVIDER=anthropic
```

### Proper Fix (to use Gemini):
Remove `*.googleapis.com` from `no_proxy` environment variable so Node.js routes through the proxy.

### Long-term Fix:
Patch agentic-flow to use `axios` instead of `fetch()` in the Gemini proxy code.

---

## Files to Update

If forking agentic-flow to fix this:

1. **src/proxy/anthropic-to-gemini.ts** (line ~56)
   - Replace `fetch()` with `axios.post()`

2. **package.json**
   - Ensure `axios` is in dependencies (already is)
   - Or add `https-proxy-agent` if keeping fetch()

3. **Add tests for proxy environment**
   - Test with `https_proxy` set
   - Test with `no_proxy` exclusions
   - Verify it works in Claude Code Remote environment

---

**Last Updated:** November 14, 2025
**Environment:** Claude Code Remote (Anthropic proxy @ 21.0.0.61:15004)
**Status:** Root cause identified, workarounds provided
