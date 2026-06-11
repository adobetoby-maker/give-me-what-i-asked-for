#!/bin/bash
# PreToolUse — Write|Edit
# Two gates:
#   1. PENDING GATE — screenshots taken but not Read → exit 2 BLOCK
#   2. SERVER-DOWN GATE — visual file edited with no server running → exit 2 BLOCK
#
# Cleared by:
#   pending → post-read-clear.sh (PNG Read)
#   server-needed → visual-gate.sh (server found on next edit)
#
# Exit 2 = BLOCK. additionalContext injected so the model knows exactly why.

PENDING="/tmp/visual-gate-pending"
SERVER_NEEDED="/tmp/visual-server-needed"
NOW=$(date +%s)

# ── Gate 1 — screenshots pending ──────────────────────────────────────────────
if [ -f "$PENDING" ]; then
  TAKEN=$(cat "$PENDING" 2>/dev/null)
  if [[ -n "$TAKEN" ]] && (( NOW - TAKEN <= 600 )); then

    python3 - << 'PYEOF'
import sys, json, glob

pngs = sorted(
    glob.glob('/tmp/preview/scroll-*.png') +
    glob.glob('/tmp/preview/vercel-*.png')
)
frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))

png_list  = '\n'.join(f'  {p}' for p in pngs[:6]) or '  (check /tmp/preview/)'
frame_tip = (
    f'\n  Key frames: {frames[0]}  {frames[len(frames)//2]}  {frames[-1]}'
    if len(frames) >= 3 else ''
)

context = (
    "┌─────────────────────────────────────────────────────────────┐\n"
    "│  EYES GATE — READ BEFORE YOU WRITE                          │\n"
    "│                                                             │\n"
    "│  Screenshots were auto-taken. You haven't opened them.      │\n"
    "│                                                             │\n"
    "│  Read these with the Read tool NOW:                         │\n"
    f"{png_list}{frame_tip}\n"
    "│                                                             │\n"
    "│  Describe section by section what you see. Then continue.   │\n"
    "│  Skipping this = iter-16 failure mode.                      │\n"
    "└─────────────────────────────────────────────────────────────┘"
)
print(json.dumps({"additionalContext": context}))
PYEOF

    exit 2
  else
    # Stale — clear and allow
    rm -f "$PENDING"
  fi
fi

# ── Gate 2 — server was not running when last visual file was edited ──────────
if [ -f "$SERVER_NEEDED" ]; then
  ENTRY=$(cat "$SERVER_NEEDED" 2>/dev/null)
  TIMESTAMP=$(echo "$ENTRY" | cut -d: -f1)

  if [[ -n "$TIMESTAMP" ]] && (( NOW - TIMESTAMP <= 600 )); then
    FILE_EDITED=$(echo "$ENTRY" | cut -d: -f2)
    PROJECT_DIR=$(echo "$ENTRY" | cut -d: -f3)

    python3 - "$FILE_EDITED" "$PROJECT_DIR" << 'PYEOF'
import sys, json, glob

file_edited  = sys.argv[1]
project_dir  = sys.argv[2]

# Check if Vercel screenshots exist as partial fallback
vercel_pngs = sorted(glob.glob('/tmp/preview/vercel-*.png'))
vercel_note = ""
if vercel_pngs:
    paths = '\n'.join(f'  {p}' for p in vercel_pngs[:3])
    vercel_note = f"\n  Vercel screenshots available (read as partial fallback):\n{paths}"

context = (
    "┌─────────────────────────────────────────────────────────────┐\n"
    "│  SERVER-DOWN GATE — START DEV SERVER BEFORE NEXT WRITE      │\n"
    "│                                                             │\n"
    f"│  {file_edited[:56]:<56} │\n"
    "│  was edited with no dev server running.                     │\n"
    "│  Cannot screenshot local build — visual output UNVERIFIED.  │\n"
    "│                                                             │\n"
    "│  Start the server:                                          │\n"
    "│    cd <project> && npm run dev -H 0.0.0.0                   │\n"
    "│  Once running, edit any visual file → auto-screenshot fires. │\n"
    f"{vercel_note}\n"
    "│                                                             │\n"
    "│  Do NOT declare done without screenshot verification.        │\n"
    "└─────────────────────────────────────────────────────────────┘"
)
print(json.dumps({"additionalContext": context}))
PYEOF

    exit 2
  else
    # Stale — clear and allow
    rm -f "$SERVER_NEEDED"
  fi
fi

exit 0
