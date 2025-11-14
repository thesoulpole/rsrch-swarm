# How to Fix research-swarm & agentic-flow

## TL;DR - Quick Fix

Use these environment variables to force direct Anthropic API usage:

```bash
USE_GEMINI=false PROVIDER=anthropic npx research-swarm research researcher "your task"
```

---

## The Problem

research-swarm uses agentic-flow internally, which has a bug in its provider selection logic. Even when you specify `--provider anthropic`, it incorrectly selects the Gemini proxy if `GOOGLE_GEMINI_API_KEY` is set in your environment.

The Gemini proxy then attempts to connect to Google's API at `https://generativelanguage.googleapis.com/v1beta`, which fails due to network restrictions, causing this error:

```
ERROR: Gemini proxy error {"error":"fetch failed"}
```

---

## Verified Working Solutions

### Solution 1: Environment Variables (Recommended)

```bash
# Single command
USE_GEMINI=false PROVIDER=anthropic npx research-swarm research researcher "your task"

# Or export for session
export USE_GEMINI=false
export PROVIDER=anthropic
npx research-swarm research researcher "your task"
```

**Verification:** Look for this in output:
```
Use Gemini: false  ← Should be false
🚀 Using direct Anthropic API...  ← Should say "direct Anthropic"
```

### Solution 2: Create Wrapper Script

```bash
# Create wrapper
cat > ~/research-swarm-fixed << 'EOF'
#!/bin/bash
export USE_GEMINI=false
export PROVIDER=anthropic
npx research-swarm "$@"
EOF

chmod +x ~/research-swarm-fixed

# Use it
~/research-swarm-fixed research researcher "your research task"
```

### Solution 3: Temporary Remove GOOGLE_GEMINI_API_KEY

```bash
# Backup
export GOOGLE_GEMINI_API_KEY_BACKUP=$GOOGLE_GEMINI_API_KEY
unset GOOGLE_GEMINI_API_KEY

# Run research-swarm (will use Anthropic by default)
npx research-swarm research researcher "your task"

# Restore
export GOOGLE_GEMINI_API_KEY=$GOOGLE_GEMINI_API_KEY_BACKUP
```

---

## Using claude-flow Instead

claude-flow might have similar issues since it shares the same codebase. Use the same workaround:

```bash
USE_GEMINI=false PROVIDER=anthropic npx claude-flow@alpha swarm "your objective"
```

---

## For agentic-flow Developers

If you want to fix this in the source code, the bug is in:

**File:** `src/cli-proxy.ts` (or `dist/cli-proxy.js` in published package)

**Function:** `shouldUseGemini()`

**Current buggy code (lines 254-263):**
```typescript
// BUG FIX: Don't auto-select Gemini if user explicitly specified a different provider
if (options.provider && options.provider !== 'gemini') {
    return false;  // This check is being bypassed somehow
}

// Auto-select Gemini fallback
if (process.env.GOOGLE_GEMINI_API_KEY &&
    !process.env.ANTHROPIC_API_KEY &&
    !process.env.OPENROUTER_API_KEY &&
    options.provider !== 'onnx') {
    return true;  // This fallback is too aggressive
}
```

**Recommended fix:**
```typescript
shouldUseGemini(options: ParsedOptions): boolean {
    // ONLY use Gemini if explicitly requested
    if (options.provider === 'gemini' || process.env.PROVIDER === 'gemini') {
        return true;
    }

    if (process.env.USE_GEMINI === 'true') {
        return true;
    }

    // Never auto-select - always return false otherwise
    return false;
}
```

---

## Testing Your Fix

```bash
# Test 1: Verify Gemini is disabled
USE_GEMINI=false PROVIDER=anthropic npx agentic-flow \
  --agent researcher \
  --task "test" \
  --verbose 2>&1 | grep "Use Gemini"
# Should output: Use Gemini: false

# Test 2: Verify Anthropic API is used
USE_GEMINI=false PROVIDER=anthropic npx agentic-flow \
  --agent researcher \
  --task "test" \
  --verbose 2>&1 | grep "Using direct"
# Should output: 🚀 Using direct Anthropic API...

# Test 3: Run actual research
USE_GEMINI=false PROVIDER=anthropic npx research-swarm \
  research researcher "test task" \
  --depth 3 --time 5
# Should complete without "fetch failed" errors
```

---

## Why This Happens

1. **agentic-flow's provider selection order:**
   - Check for ONNX
   - Check for Requesty (disabled)
   - Check for Gemini ← **BUG HERE**
   - Check for OpenRouter
   - Fall back to direct Anthropic

2. **The bug:** `shouldUseGemini()` has auto-detection logic that checks for `GOOGLE_GEMINI_API_KEY` in the environment, even when `--provider anthropic` is explicitly specified.

3. **Why it fails:** The Gemini proxy tries to fetch from Google's API, but network connectivity to external APIs is blocked or unavailable.

---

## Environment Setup Reference

Make sure these are set:

```bash
# Required
export ANTHROPIC_API_KEY="sk-ant-..."

# Optional (but causes the bug if set)
export GOOGLE_GEMINI_API_KEY="..."
export OPENROUTER_API_KEY="..."

# Fix: Add these to force Anthropic
export USE_GEMINI=false
export PROVIDER=anthropic
```

---

## Related Issue

If you want to report this upstream:

**Repository:** https://github.com/ruvnet/agentic-flow
**Issue Title:** "Provider selection incorrectly chooses Gemini when --provider anthropic is specified"
**Priority:** High (blocks research-swarm functionality)

---

## Full Example

```bash
# Set up environment
export ANTHROPIC_API_KEY="your-key-here"
export USE_GEMINI=false
export PROVIDER=anthropic

# Run research-swarm
npx research-swarm research researcher \
  "agentic coding frameworks that orchestrate agents" \
  --depth 7 \
  --time 30 \
  --swarm-size 5 \
  --verbose

# Output should show:
# ✓ Use Gemini: false
# ✓ 🚀 Using direct Anthropic API...
# ✓ Research starts without fetch errors
```

---

## Additional Resources

- Full technical analysis: See `RESEARCH_SWARM_ANALYSIS.md`
- Research findings: See `AGENTIC_CODING_FRAMEWORKS_RESEARCH.md`
- agentic-flow repository: https://github.com/ruvnet/agentic-flow
- research-swarm docs: https://github.com/ruvnet/agentic-flow/tree/main/examples/research-swarm

---

**Last Updated:** November 13, 2025
**Status:** Workaround verified and working
**Fix Needed:** Provider selection logic in agentic-flow
