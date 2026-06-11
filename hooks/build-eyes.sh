#!/bin/bash
# PostToolUse — Bash
# Fires after npm build / tsc / next build / npm run dev / vite dev.
#
# On BUILD SUCCESS:
#   - Screenshots Vercel URL if .vercelurl exists
#   - Arms /tmp/visual-gate-pending so next Write/Edit is blocked until PNGs Read
#   - Injects "build passed — screenshot before done" reminder
#
# On DEV SERVER START:
#   - Clears /tmp/visual-server-needed (server is now up)
#   - Takes immediate screenshot of localhost
#   - Arms pending flag
#
# Does NOT fire on: curl, git, install, deploy, or other bash commands

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

# Only fire on build / dev / type-check commands
IS_BUILD=false
IS_DEV=false

if echo "$COMMAND_STR" | grep -qiE "(npm run build|next build|vite build|wrangler build|npx tsc|tsc --no)"; then
  IS_BUILD=true
fi

if echo "$COMMAND_STR" | grep -qiE "(npm run dev|next dev|vite( dev)?|npx next dev)"; then
  IS_DEV=true
fi

[[ "$IS_BUILD" == "false" && "$IS_DEV" == "false" ]] && exit 0

# Extract tool result to check success/failure
TOOL_OUTPUT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    resp = d.get('tool_response', d.get('tool_result', {}))
    if isinstance(resp, dict):
        out = resp.get('stdout', '') + resp.get('output', '') + resp.get('stderr', '')
    else:
        out = str(resp)
    print(out[:2000])
except:
    print('')
" 2>/dev/null)

BUILD_SUCCESS=false
if echo "$TOOL_OUTPUT" | grep -qiE "(compiled successfully|build complete|✓ compiled|Compiled|✓ Compiled|ready started|ready in|Local:)"; then
  BUILD_SUCCESS=true
fi
# Also consider success if output doesn't contain "error" and command exited (for tsc --noEmit producing no output)
if [[ "$IS_BUILD" == "true" ]] && ! echo "$TOOL_OUTPUT" | grep -qiE "( error | Error | ERROR |✗|failed|FAILED)"; then
  BUILD_SUCCESS=true
fi

[[ "$BUILD_SUCCESS" == "false" ]] && exit 0

# ── Find port (for dev server) ─────────────────────────────────────────────────
DEV_PORT=""
if [[ "$IS_DEV" == "true" ]]; then
  # Try to extract port from command output first
  EXTRACTED=$(echo "$TOOL_OUTPUT" | grep -oE '(localhost|127\.0\.0\.1):[0-9]+' | head -1 | grep -oE '[0-9]+$')
  DEV_PORT="${EXTRACTED}"

  # Fallback: scan common ports
  if [ -z "$DEV_PORT" ]; then
    for port in 3000 3001 3002 3003 3004 3005 4000 5173 8080; do
      if lsof -ti :"$port" > /dev/null 2>&1; then
        if curl -s --max-time 1 "http://localhost:$port" > /dev/null 2>&1; then
          DEV_PORT=$port
          break
        fi
      fi
    done
  fi

  if [ -n "$DEV_PORT" ]; then
    # Server just started — clear the server-needed flag
    rm -f /tmp/visual-server-needed
  fi
fi

# ── Find Vercel URL (walk up from cwd) ─────────────────────────────────────────
VERCEL_URL=""
SEARCH_DIR="$PWD"
for _ in 1 2 3 4 5; do
  [[ -z "$SEARCH_DIR" || "$SEARCH_DIR" == "/" ]] && break
  if [ -f "$SEARCH_DIR/.vercelurl" ]; then
    VERCEL_URL=$(tr -d '[:space:]' < "$SEARCH_DIR/.vercelurl")
    break
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

# ── Capture ────────────────────────────────────────────────────────────────────
mkdir -p /tmp/preview /tmp/preview/frames
find /tmp/preview -maxdepth 1 -name "*.png" -mmin +30 -delete 2>/dev/null

LOCAL_SHOT_EXIT=1
VERCEL_SHOT_EXIT=1

if [ -n "$DEV_PORT" ]; then
  node ~/screenshot.js "$DEV_PORT" 0,540,1080 > /tmp/screenshot-build-gate.log 2>&1
  LOCAL_SHOT_EXIT=$?
  [ $LOCAL_SHOT_EXIT -eq 0 ] && date +%s > /tmp/visual-gate-pending
fi

if [ -n "$VERCEL_URL" ]; then
  node ~/screenshot.js "$VERCEL_URL" 0,540,1080 --prefix vercel > /tmp/screenshot-vercel-build.log 2>&1
  VERCEL_SHOT_EXIT=$?
  # Arm pending flag if we got vercel screenshots but no local
  if [ $VERCEL_SHOT_EXIT -eq 0 ] && [ $LOCAL_SHOT_EXIT -ne 0 ]; then
    date +%s > /tmp/visual-gate-pending
  fi
fi

# ── Inject context ─────────────────────────────────────────────────────────────
python3 - "$IS_BUILD" "$IS_DEV" "$DEV_PORT" "$VERCEL_URL" "$LOCAL_SHOT_EXIT" "$VERCEL_SHOT_EXIT" "$BUILD_SUCCESS" << 'PYEOF'
import sys, json, glob

is_build        = sys.argv[1] == "true"
is_dev          = sys.argv[2] == "true"
port            = sys.argv[3]
vercel_url      = sys.argv[4]
local_shot_exit = int(sys.argv[5])
vercel_shot_exit = int(sys.argv[6])
build_success   = sys.argv[7] == "true"

if not build_success:
    sys.exit(0)

parts = []
event = "BUILD PASSED" if is_build else "DEV SERVER STARTED"

# Local screenshots
if local_shot_exit == 0:
    pngs = sorted(glob.glob('/tmp/preview/scroll-*.png'))
    if pngs:
        paths = '\n'.join(f'  {p}' for p in pngs[:4])
        parts.append(f"LOCAL SCREENSHOTS (:{port}) — Read each:\n{paths}")
elif port:
    parts.append(
        f"screenshot.js FAILED on :{port}\n"
        f"  Run manually: node ~/screenshot.js {port} 0,540,1080"
    )
elif is_build:
    parts.append(
        "No local server running — start with npm run dev to screenshot local build.\n"
        "Or check Vercel screenshots below (deployed build verification)."
    )

# Vercel screenshots
if vercel_url and vercel_shot_exit == 0:
    vpngs = sorted(glob.glob('/tmp/preview/vercel-*.png'))
    if vpngs:
        vpaths = '\n'.join(f'  {p}' for p in vpngs[:4])
        parts.append(
            f"VERCEL SCREENSHOTS ({vercel_url}) — Read each:\n{vpaths}\n"
            "  Compare: layout, fonts, image loading, contrast."
        )
elif vercel_url:
    parts.append(
        f"Vercel screenshot FAILED ({vercel_url})\n"
        f"  Run: node ~/screenshot.js '{vercel_url}' 0,540,1080 --prefix vercel"
    )
elif not vercel_url:
    parts.append(
        "No .vercelurl file — add one for automatic deployed build verification:\n"
        "  echo 'https://your-project.vercel.app' > .vercelurl"
    )

context = (
    f"BUILD EYES — {event}\n\n"
    + '\n\n'.join(parts)
    + "\n\nDo NOT declare done until you have:\n"
    + "  □ Read the screenshots above\n"
    + "  □ Described what is visible section by section\n"
    + "  □ Confirmed no regressions at mobile + desktop viewports\n"
    + "\neyeS-precheck.sh is ARMED — next Write/Edit blocked until PNGs Read."
)
print(json.dumps({"additionalContext": context}))
PYEOF
