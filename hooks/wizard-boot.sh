#!/bin/bash
# PreToolUse — browser_navigate|browser_snapshot|browser_take_screenshot|browser_evaluate
# Injects the Wizard EYES protocol before any browser action.
# Ensures the full video+frame protocol is followed, not just static screenshots.

INPUT=$(cat)
URL=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    # browser_navigate has 'url', browser_take_screenshot has 'name', others vary
    print(inp.get('url', inp.get('selector', '')))
except:
    print('')
" 2>/dev/null)

python3 - "$URL" << 'PYEOF'
import sys, json

url = sys.argv[1]
target = f" → {url}" if url and url.startswith('http') else ""

context = (
    f"WIZARD EYES PROTOCOL{target}\n\n"
    "Before reporting any visual finding from this page:\n\n"
    "1. RECORD — not just screenshot:\n"
    "   node ~/.command/shortcuts/record-url.js '<url>' eyes-desktop\n"
    "   node ~/.command/shortcuts/record-url.js '<url>' eyes-mobile --mobile\n\n"
    "2. EXTRACT frames:\n"
    "   ffmpeg -i ~/.command/screenshots/eyes-desktop.webm -vf fps=2 ~/.command/screenshots/frame_%03d.png\n\n"
    "3. READ key frames:\n"
    "   - frame_001 (above fold)\n"
    "   - frame at midpoint (mid-page)\n"
    "   - final 3 frames (footer zone)\n\n"
    "4. FOOTER CHECK — final frame must show footer.\n"
    "   If not: harness scroll is broken. Fix it.\n\n"
    "FORBIDDEN shortcuts:\n"
    "  ✗ curl body as visual proof — SPA renders blank\n"
    "  ✗ HTTP 200 as EYES confirmation — status ≠ rendered page\n"
    "  ✗ Single static screenshot on animated pages\n"
    "  ✗ Desktop-only — mobile carries equal weight\n\n"
    "Static screenshot alone = incomplete verification. Video is ground truth."
)
print(json.dumps({"additionalContext": context}))
PYEOF
