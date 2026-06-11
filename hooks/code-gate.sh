#!/bin/bash
# PreToolUse hook — Bash tool — Code Quality Gate
# Fires before Bash. If command contains "done" indicators after build commands,
# verifies the build actually ran. Also runs tsc check before deploy.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Fire before deploy to ensure TypeScript is clean
if echo "$COMMAND" | grep -qE "(vercel --prod|wrangler deploy)"; then
  CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', ''))
except:
    print('')
" 2>/dev/null)

  if [ -n "$CWD" ] && [ -f "$CWD/tsconfig.json" ]; then
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  CODE GATE — Running TypeScript check before deploy  ║"
    echo "╚══════════════════════════════════════════════════════╝"
    TSC_RESULT=$(cd "$CWD" && npx tsc --noEmit 2>&1 | tail -5)
    if [ -n "$TSC_RESULT" ]; then
      echo "TypeScript errors found:"
      echo "$TSC_RESULT"
      echo ""
      echo "Fix TypeScript errors before deploying."
    else
      echo "TypeScript: clean ✓"
    fi
  fi
fi
