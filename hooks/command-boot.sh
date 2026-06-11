#!/bin/bash
# PreToolUse — Bash (COMMAND sessions)
# Catches mission-completion and deploy commands before EYES is satisfied.
# Fires when: vercel deploy, curl -sI, "done", mission logging, iMessage reports.

INPUT=$(cat)
COMMAND_STR=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

[[ -z "$COMMAND_STR" ]] && exit 0

# Only fire on mission-completion signals
if ! echo "$COMMAND_STR" | grep -qiE \
  "(vercel.*--prod|wrangler.*deploy|curl.*-sI|active\.log|queue\.md|mission.*complete|done.*logged|task complete|echo.*done|iMessage.*complete|dispatch.*done|poll-tac)"; then
  exit 0
fi

# Check if visual-gate-pending exists (screenshots taken but not Read)
PENDING="/tmp/visual-gate-pending"
PENDING_ACTIVE=false
if [ -f "$PENDING" ]; then
  TAKEN=$(cat "$PENDING" 2>/dev/null)
  NOW=$(date +%s)
  if [[ -n "$TAKEN" ]] && (( NOW - TAKEN <= 600 )); then
    PENDING_ACTIVE=true
  fi
fi

python3 - "$COMMAND_STR" "$PENDING_ACTIVE" << 'PYEOF'
import sys, json, glob

cmd            = sys.argv[1][:80]
pending_active = sys.argv[2] == "true"

parts = []

if pending_active:
    pngs = sorted(glob.glob('/tmp/preview/scroll-*.png') + glob.glob('/tmp/preview/vercel-*.png'))
    png_list = '\n'.join(f'  {p}' for p in pngs[:4]) or '  (check /tmp/preview/)'
    parts.append(
        "EYES GATE OPEN — screenshots taken but not Read.\n"
        f"Read these before this command proceeds:\n{png_list}"
    )

parts.append(
    "COMMAND EYES CHECK — mission/deploy detected.\n"
    "Required before 'Done. Logged.':\n"
    "  □ Code change → tsc passes + live URL returns 200\n"
    "  □ UI change   → Wizard: 4 viewports + footer in final frame\n"
    "  □ Deploy      → curl -sI <live-url> confirms 200\n"
    "               → Wizard confirms rendered output (not just HTTP)\n\n"
    "Observable proof required. Process completion ≠ observable proof."
)

context = '\n\n'.join(parts)
print(json.dumps({"additionalContext": context}))
PYEOF
