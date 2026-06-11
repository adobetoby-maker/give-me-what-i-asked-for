#!/bin/bash
# MessageDisplay hook
# Fires as every assistant message renders.
# If message contains done/complete/finished/shipped/fixed AND a visual gate is armed:
#   → appends a visible warning to the rendered message
#   → warning appears in conversation history → model sees it was flagged next turn
#   → writes /tmp/skipped-gate for Stop hook and next prompt-gate injection

INPUT=$(cat)
NOW=$(date +%s)

# ── Check pending flags ────────────────────────────────────────────────────────
PENDING_EXISTS=false
SERVER_DOWN_EXISTS=false

if [ -f /tmp/visual-gate-pending ]; then
  TAKEN=$(cat /tmp/visual-gate-pending 2>/dev/null)
  if [[ -n "$TAKEN" ]] && (( NOW - TAKEN <= 600 )); then
    PENDING_EXISTS=true
  fi
fi

if [ -f /tmp/visual-server-needed ]; then
  ENTRY=$(cat /tmp/visual-server-needed 2>/dev/null)
  TS=$(echo "$ENTRY" | cut -d: -f1)
  if [[ -n "$TS" ]] && (( NOW - TS <= 600 )); then
    SERVER_DOWN_EXISTS=true
  fi
fi

# If no gate is armed, pass through
if [[ "$PENDING_EXISTS" == "false" && "$SERVER_DOWN_EXISTS" == "false" ]]; then
  echo '{"action": "show"}'
  exit 0
fi

# ── Check if message contains a done/complete signal ─────────────────────────
MESSAGE_TEXT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message', '')
    if isinstance(msg, list):
        text = ' '.join(
            b.get('text', '') for b in msg
            if isinstance(b, dict) and b.get('type') == 'text'
        )
    elif isinstance(msg, dict):
        content = msg.get('content', '')
        if isinstance(content, list):
            text = ' '.join(
                b.get('text', '') for b in content
                if isinstance(b, dict) and b.get('type') == 'text'
            )
        else:
            text = str(content)
    else:
        text = str(msg)
    print(text[:1000])
except Exception as e:
    print('')
" 2>/dev/null)

if ! echo "$MESSAGE_TEXT" | grep -qiE "\b(done|complete|completed|finished|it works|it's working|shipped|ready|deployed|verified|all set|looks good|working now|fixed|resolved|implemented|added|built|created|updated)\b"; then
  echo '{"action": "show"}'
  exit 0
fi

# ── Gate was skipped — write skipped-gate file for next prompt-gate pass ──────
echo "$NOW:$PENDING_EXISTS:$SERVER_DOWN_EXISTS" > /tmp/skipped-gate

# ── Build warning text and transform the message ──────────────────────────────
python3 - "$PENDING_EXISTS" "$SERVER_DOWN_EXISTS" "$MESSAGE_TEXT" << 'PYEOF'
import sys, json, glob

pending     = sys.argv[1] == "true"
server_down = sys.argv[2] == "true"
original    = sys.argv[3]

warnings = []

if pending:
    pngs = sorted(
        glob.glob('/tmp/preview/scroll-*.png') +
        glob.glob('/tmp/preview/vercel-*.png')
    )
    frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))
    png_list = '\n'.join(f'  {p}' for p in pngs[:4]) or '  (none found — check /tmp/preview/)'
    frame_note = f'\n  Video frames: {frames[0]} … {frames[-1]}' if len(frames) >= 2 else ''
    warnings.append(
        "⚠️  EYES GATE SKIPPED — screenshots were taken but NOT Read before this response.\n"
        f"Unverified files:\n{png_list}{frame_note}\n"
        "This response cannot be trusted as 'done'. Read the PNGs and re-verify."
    )

if server_down:
    warnings.append(
        "⚠️  SERVER-DOWN GATE SKIPPED — last visual edit had no dev server running.\n"
        "Local build was never screenshotted. Visual output is UNVERIFIED.\n"
        "Start the server, trigger a re-screenshot, then redeclare done."
    )

warning_block = (
    "\n\n---\n"
    "## GATE VIOLATION — Visual Verification Not Complete\n\n"
    + "\n\n".join(warnings)
    + "\n\n"
    "**To clear this:** Read the PNG files above. Describe what you see. Then say done.\n"
    "---"
)

# Return transform action with original + appended warning
result = {
    "action": "transform",
    "content": original + warning_block
}
print(json.dumps(result))
PYEOF
