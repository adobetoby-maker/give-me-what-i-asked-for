#!/bin/bash
# PreToolUse hook — Bash tool — Deploy Gate
# Fires before any Bash call containing a deploy command.
# Gate 1: [DEMO] tag check — hard block if placeholder content exists
# Gate 2: Platform decision — Vercel vs Cloudflare Workers
# Gate 3: Auth check — verify credentials present
# Gate 4: SEO flag — arm /tmp/seo-check-needed for post-deploy check
# Rules: client-handoff-protocol.md, demo-to-live-protocol.md, ADR-0014

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only fire on deploy commands
if ! echo "$COMMAND" | grep -qE "(vercel --prod|vercel deploy --prod|wrangler deploy|npx wrangler deploy|opennextjs-cloudflare)"; then
  exit 0
fi

CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', ''))
except:
    print('')
" 2>/dev/null)

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  DEPLOY GATE — ADR-0014 / client-handoff / quality-gate   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ── Gate 1: [DEMO] tag scan ─────────────────────────────────────────────────
# Hard block: demo content shipping to production is a client trust failure.
if [ -n "$CWD" ]; then
  DEMO_COUNT=0
  for dir in "$CWD/app" "$CWD/src" "$CWD/components" "$CWD/pages" "$CWD/lib"; do
    if [ -d "$dir" ]; then
      DEMO_COUNT=$((DEMO_COUNT + $(grep -rn "\[DEMO\]" "$dir" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')))
    fi
  done

  if [ "$DEMO_COUNT" -gt 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  ⛔ DEMO GATE — HARD BLOCK                                 ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  $DEMO_COUNT [DEMO] placeholder(s) found in source."
    echo "  Demo content must never ship to production."
    echo ""
    echo "  First locations:"
    for dir in "$CWD/app" "$CWD/src" "$CWD/components"; do
      [ -d "$dir" ] && grep -rn "\[DEMO\]" "$dir" 2>/dev/null | grep -v "node_modules" | head -3
    done
    echo ""
    echo "  Fix all [DEMO] tags then re-run the deploy."
    echo "  Find them: grep -rn '[DEMO]' app/ src/ components/ | grep -v node_modules"
    echo ""
    exit 2
  fi

  echo "  [DEMO] tags: none ✓"
fi

# ── Gate 2: Platform decision ────────────────────────────────────────────────
WRANGLER_FILE="${CWD}/wrangler.jsonc"
[ ! -f "$WRANGLER_FILE" ] && WRANGLER_FILE="${CWD}/wrangler.json"

HAS_BINDINGS=""
if [ -f "$WRANGLER_FILE" ]; then
  HAS_BINDINGS=$(grep -E "d1_databases|r2_buckets|kv_namespaces" "$WRANGLER_FILE" 2>/dev/null | head -1)
fi

if [ -n "$HAS_BINDINGS" ]; then
  echo "  Platform: Cloudflare Workers (D1/R2/KV bindings detected)"
  CFTOKEN=$(env | grep "^CLOUDFLARE_API_TOKEN=" | head -1)
  if [ -z "$CFTOKEN" ]; then
    echo "  ⚠ CLOUDFLARE_API_TOKEN not in env — deploy will fail"
    echo "  Run Iron Law 2 fallback sequence before retrying."
  else
    echo "  CLOUDFLARE_API_TOKEN: present ✓"
  fi
else
  echo "  Platform: No D1/R2/KV → Vercel"
  VERCEL_AUTH=$(vercel whoami 2>/dev/null | tr -d '\n')
  if [ -n "$VERCEL_AUTH" ]; then
    echo "  Vercel auth: $VERCEL_AUTH ✓"
  else
    echo "  ⚠ Vercel auth not cached — may need: ! vercel login"
  fi
fi

# ── Gate 3: SEO flag — arm for post-deploy check ────────────────────────────
# quality-gate.md Gate 3: SEO check required on new public pages
if [ -n "$CWD" ]; then
  # Find .vercelurl or extract from vercel project
  VERCEL_URL=""
  if [ -f "$CWD/.vercelurl" ]; then
    VERCEL_URL=$(tr -d '[:space:]' < "$CWD/.vercelurl")
  fi
  if [ -n "$VERCEL_URL" ]; then
    echo "$(date +%s):$VERCEL_URL" > /tmp/seo-check-needed
    echo "  SEO gate: armed — will run after deploy completes"
  else
    echo "  SEO gate: no .vercelurl file — add one for auto SEO check"
  fi
fi

echo ""
echo "  Post-deploy: curl -sI <live-url> | head -1 must return HTTP 200"
echo "  Post-deploy SEO: curl -s <url> | grep -E '<title>|description|canonical|og:'"
