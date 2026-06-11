#!/bin/bash
# PreToolUse — Write|Edit
# Blocks the next file write if screenshots were auto-taken but not yet Read.
# Cleared by post-read-clear.sh when the model opens a PNG from /tmp/preview/.
#
# Exit 2 = BLOCK. additionalContext is injected so the model knows exactly why.

PENDING="/tmp/visual-gate-pending"

[[ ! -f "$PENDING" ]] && exit 0

# Read timestamp written by visual-gate.sh
TAKEN=$(cat "$PENDING" 2>/dev/null)
NOW=$(date +%s)

# Stale after 10 minutes — clear and allow through
if [[ -z "$TAKEN" ]] || (( NOW - TAKEN > 600 )); then
  rm -f "$PENDING"
  exit 0
fi

# Screenshots exist and are recent — BLOCK until Read
python3 - << 'PYEOF'
import sys, json, glob

pngs = sorted(
    glob.glob('/tmp/preview/scroll-*.png') +
    glob.glob('/tmp/preview/vercel-*.png')
)
frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))

png_list  = '\n'.join(f'  {p}' for p in pngs[:6])   or '  (check /tmp/preview/)'
frame_tip = f'\n  Key frames: {frames[0]}  {frames[len(frames)//2]}  {frames[-1]}' if len(frames) >= 3 else ''

context = (
    "┌─────────────────────────────────────────────────────────────┐\n"
    "│  EYES GATE — READ BEFORE YOU WRITE                          │\n"
    "│                                                             │\n"
    "│  Screenshots were auto-taken from your last visual change.  │\n"
    "│  You have not opened them yet.                              │\n"
    "│                                                             │\n"
    "│  Read these files with the Read tool FIRST:                 │\n"
    f"{png_list}{frame_tip}\n"
    "│                                                             │\n"
    "│  Describe section by section what you see.                  │\n"
    "│  Then continue writing.                                     │\n"
    "│                                                             │\n"
    "│  Skipping this = the same failure mode as iter-16.          │\n"
    "└─────────────────────────────────────────────────────────────┘"
)
print(json.dumps({"additionalContext": context}))
PYEOF

exit 2
