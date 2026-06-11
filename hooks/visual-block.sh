#!/bin/bash
# PreToolUse — Bash
# Blocks git commit, vercel deploy, and "done" declarations
# when a visual gate marker exists (i.e. .tsx/.css was edited without a screenshot run)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only check blocking commands
if ! echo "$COMMAND" | grep -qE \
  "(git (commit|push|add -A)|vercel --prod|vercel deploy|wrangler deploy|npm run build)"; then
  exit 0
fi

# Check for any armed visual gate markers
MARKERS=$(ls /tmp/visual-gate-* 2>/dev/null)
if [ -z "$MARKERS" ]; then
  exit 0
fi

# Gate is armed — collect which files are pending
PENDING=$(cat $MARKERS 2>/dev/null | sort -u | head -5)

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ⛔  VISUAL GATE BLOCKED                                         ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Visual files were edited without a screenshot run.             ║"
echo "║                                                                  ║"
echo "║  Pending files:                                                  ║"
echo "$PENDING" | while read -r f; do
  printf "║    %-62s║\n" "• $(basename "$f")"
done
echo "║                                                                  ║"
echo "║  Run this first:                                                 ║"
echo "║    node ~/screenshot.js <port> 0,540,1080                       ║"
echo "║    node ~/record.js <port>                                       ║"
echo "║    node ~/record.js <port> --mobile                             ║"
echo "║    Read all PNGs. Describe what you see.                        ║"
echo "║                                                                  ║"
echo "║  The visual check is not optional. It takes 30 seconds.         ║"
echo "║  Humans interact through their eyes. You have screenshot tools. ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Exit 2 = block the tool call
exit 2
