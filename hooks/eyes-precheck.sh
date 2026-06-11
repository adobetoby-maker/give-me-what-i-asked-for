#!/bin/bash
# PreToolUse — Write | Edit | Bash
#
# Three gates (all exit 2 = BLOCK, all inject additionalContext so the model
# knows exactly why and what to Read):
#
#   1. PENDING GATE        — screenshots taken but not Read → BLOCK next Write/Edit/Bash
#   2. SERVER-DOWN GATE    — visual file edited with no server running → BLOCK
#   3. FINISH-COMMAND GATE — (Bash only) a "finishing" command (git commit, deploy,
#                            push, or the honesty-ritual gate-check itself) is about to
#                            run while a gate is ARMED → BLOCK. This is the structural
#                            close for the "done-in-text" bypass: the HONESTY injection
#                            tells Claude to run `ls /tmp/visual-gate-pending` before
#                            declaring done. When it does, THIS hook intercepts that very
#                            command and turns the ritual into a hard stop — Claude cannot
#                            run the check, see the file, and then ignore it.
#
# Cleared by:
#   pending       → post-read-clear.sh (PNG Read deletes /tmp/visual-gate-pending)
#   server-needed → visual-gate.sh (server found on next edit)

PENDING="/tmp/visual-gate-pending"
SERVER_NEEDED="/tmp/visual-server-needed"
NOW=$(date +%s)

# ── Parse the incoming tool call ───────────────────────────────────────────────
INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null)
BASH_CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

# ── Helper: is a pending-screenshot gate currently armed? ──────────────────────
pending_armed() {
  [ -f "$PENDING" ] || return 1
  local taken; taken=$(cat "$PENDING" 2>/dev/null)
  [[ -n "$taken" ]] && (( NOW - taken <= 600 ))
}
server_armed() {
  [ -f "$SERVER_NEEDED" ] || return 1
  local entry ts; entry=$(cat "$SERVER_NEEDED" 2>/dev/null); ts=$(echo "$entry" | cut -d: -f1)
  [[ -n "$ts" ]] && (( NOW - ts <= 600 ))
}

# ── BASH branch ────────────────────────────────────────────────────────────────
# Only intercept Bash when a gate is armed AND the command is a "finishing" or
# "gate-check" command. We do NOT block arbitrary Bash — that would break the
# model's ability to actually Read screenshots, start servers, run captures, etc.
if [ "$TOOL_NAME" = "Bash" ]; then

  # Commands the model legitimately needs WHILE a gate is armed — never block these.
  # (reading/capturing/serving/clearing paths out of the gate)
  if echo "$BASH_CMD" | grep -qiE '(screenshot\.js|record\.js|ffmpeg|npm run dev|next dev|vite|lsof|curl .*localhost|\.devport|\.vercelurl)'; then
    exit 0
  fi

  if pending_armed || server_armed; then

    # Is this a "finishing" command — the moment just before done is declared?
    # git commit / push / deploy / vercel / wrangler, OR the honesty-ritual gate-check
    # (ls /tmp/visual-gate-pending). Any of these while armed = block.
    if echo "$BASH_CMD" | grep -qiE '(git commit|git push|vercel( |$)|wrangler|deploy|/tmp/visual-gate-pending|/tmp/visual-server-needed|/tmp/skipped-gate)'; then

      python3 - "$BASH_CMD" << 'PYEOF'
import sys, json, glob

cmd = sys.argv[1][:120]
pngs = sorted(
    glob.glob('/tmp/preview/scroll-*.png') +
    glob.glob('/tmp/preview/vercel-*.png')
)
frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))
png_list  = '\n'.join(f'  {p}' for p in pngs[:6]) or '  (re-run: node ~/screenshot.js <port> 0,540,1080)'
frame_tip = (
    f"\n  Frames: {frames[0]}  {frames[len(frames)//2]}  {frames[-1]}"
    if len(frames) >= 3 else ''
)

context = (
    "EYES GATE — FINISH BLOCKED.\n\n"
    f"You are about to run: {cmd}\n\n"
    "A visual gate is ARMED — screenshots were auto-captured this turn and you\n"
    "have NOT Read them. You do not get to commit, deploy, or even run the\n"
    "gate-check ritual and move on. Reading the screenshots is the only path\n"
    "through this gate.\n\n"
    "Read these NOW with the Read tool (each PNG):\n"
    f"{png_list}{frame_tip}\n\n"
    "Describe section by section what you see. Reading any preview PNG clears\n"
    "the gate. THEN you may finish — confirming or correcting your completion\n"
    "claim from what the pixels actually show. This is the iter-16 failure mode\n"
    "if you skip it."
)
print(json.dumps({"additionalContext": context}))
PYEOF

      exit 2
    fi
  fi

  # Bash, but not a finishing command or no gate armed → allow.
  exit 0
fi

# ── WRITE / EDIT branch (original behavior) ────────────────────────────────────

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
