#!/bin/bash
# Stop hook — BLOCKING
# Fires at the end of every Claude turn (including turns that end in plain text
# with NO trailing Write/Edit — the one case eyes-precheck.sh structurally cannot catch).
#
# This is the forcing function for the "done-in-text" gap:
#   eyes-precheck.sh only fires on Write|Edit. If Claude writes "Done! Looks great."
#   and stops — no tool call follows, so the PreToolUse block never arms.
#   The Stop hook fires at exactly that moment. By returning {"decision":"block"}
#   we REFUSE to let the turn end and send Claude back into the loop with the
#   screenshot paths injected. The user never sees the premature "done".
#
# Block budget: we block at most STOP_BLOCK_MAX times per armed-gate episode so a
# wedged capture (e.g. PNGs already purged, server permanently down) cannot trap the
# session in an infinite Stop→reason→Stop loop. After the budget is spent we fall
# back to the legacy behavior: write /tmp/skipped-gate for the next prompt-gate pass.
#
# Cleared by: post-read-clear.sh deleting /tmp/visual-gate-pending when a PNG is Read.

NOW=$(date +%s)
PENDING="/tmp/visual-gate-pending"
SERVER_NEEDED="/tmp/visual-server-needed"
BLOCK_COUNT_FILE="/tmp/stop-gate-blocks"
STOP_BLOCK_MAX=3

# stop_hook_active guard: Claude Code sets this in the payload when the current
# turn was itself triggered by a Stop-hook block. If we see it, we are already
# inside a forced continuation — never block again on the same payload, just exit
# cleanly to avoid runaway loops the harness can't break out of.
INPUT=$(cat 2>/dev/null)
STOP_ACTIVE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print('true' if d.get('stop_hook_active') else 'false')
except Exception:
    print('false')
" 2>/dev/null)

SKIPPED=false
REASON=""
PENDING_ARMED=false
SERVER_ARMED=false

if [ -f "$PENDING" ]; then
  TAKEN=$(cat "$PENDING" 2>/dev/null)
  if [[ -n "$TAKEN" ]] && (( NOW - TAKEN <= 600 )); then
    SKIPPED=true
    PENDING_ARMED=true
    REASON="pending-screenshots"
  fi
fi

if [ -f "$SERVER_NEEDED" ]; then
  ENTRY=$(cat "$SERVER_NEEDED" 2>/dev/null)
  TS=$(echo "$ENTRY" | cut -d: -f1)
  if [[ -n "$TS" ]] && (( NOW - TS <= 600 )); then
    SKIPPED=true
    SERVER_ARMED=true
    REASON="${REASON:+$REASON+}server-down"
  fi
fi

# No gate armed → clean exit, reset block budget for the next episode.
if [ "$SKIPPED" = "false" ]; then
  rm -f "$BLOCK_COUNT_FILE"
  exit 0
fi

# A gate is armed and the turn is trying to end. Decide: block or fall back.

# Read current block count (per armed-gate episode).
BLOCKS=0
if [ -f "$BLOCK_COUNT_FILE" ]; then
  BLOCKS=$(cat "$BLOCK_COUNT_FILE" 2>/dev/null)
  [[ "$BLOCKS" =~ ^[0-9]+$ ]] || BLOCKS=0
fi

# Always leave the legacy breadcrumb so prompt-gate.sh stays a backstop even when
# blocking is in effect or has been exhausted.
echo "$NOW:$REASON" > /tmp/skipped-gate

# If we're already in a forced continuation, or we've spent the block budget,
# stop blocking — let the turn end and rely on prompt-gate's next-turn injection.
if [ "$STOP_ACTIVE" = "true" ] || (( BLOCKS >= STOP_BLOCK_MAX )); then
  exit 0
fi

# Otherwise BLOCK the turn from ending. Increment the budget counter.
echo "$((BLOCKS + 1))" > "$BLOCK_COUNT_FILE"

# Build the block reason with concrete file paths so Claude knows exactly what to Read.
python3 - "$PENDING_ARMED" "$SERVER_ARMED" "$BLOCKS" "$STOP_BLOCK_MAX" << 'PYEOF'
import sys, json, glob

pending_armed = sys.argv[1] == "true"
server_armed  = sys.argv[2] == "true"
blocks        = int(sys.argv[3])
block_max     = int(sys.argv[4])

lines = []
lines.append("STOP BLOCKED — you are ending this turn with a visual gate still ARMED.")
lines.append("")
lines.append("You declared completion (or stopped) without Reading the screenshots that")
lines.append("were auto-captured for the visual changes in this turn. This is the exact")
lines.append("'done-in-text, no tool call' bypass the eyes architecture exists to stop.")
lines.append("")

if pending_armed:
    pngs = sorted(
        glob.glob('/tmp/preview/scroll-*.png') +
        glob.glob('/tmp/preview/vercel-*.png')
    )
    frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))
    if pngs:
        lines.append("READ THESE NOW with the Read tool (each PNG, one by one):")
        for p in pngs[:6]:
            lines.append(f"  {p}")
    else:
        lines.append("Screenshots were taken but are no longer on disk — re-run the capture:")
        lines.append("  node ~/screenshot.js <port> 0,540,1080")
    if len(frames) >= 3:
        lines.append("")
        lines.append("Video frames (Read first, middle, and final 3 — footer must be in the last):")
        lines.append(f"  {frames[0]}")
        lines.append(f"  {frames[len(frames)//2]}")
        for f in frames[-3:]:
            lines.append(f"  {f}")

if server_armed:
    lines.append("")
    lines.append("SERVER WAS DOWN during the last visual edit — local build was never")
    lines.append("screenshotted. Start the dev server, then re-edit a visual file to fire")
    lines.append("the auto-capture, OR Read the Vercel fallback screenshots if present:")
    vpngs = sorted(glob.glob('/tmp/preview/vercel-*.png'))
    for p in vpngs[:3]:
        lines.append(f"  {p}")

lines.append("")
lines.append("Reading any preview PNG clears this gate (post-read-clear.sh). After you")
lines.append("Read them and describe what you see, you may finish — confirming or")
lines.append("CORRECTING the completion claim based on what the pixels actually show.")
lines.append("")
lines.append(f"(Stop-block {blocks + 1}/{block_max}. After {block_max}, the gate falls back to")
lines.append(" a next-turn injection so the session can never be permanently trapped.)")

print(json.dumps({"decision": "block", "reason": "\n".join(lines)}))
PYEOF

exit 0
