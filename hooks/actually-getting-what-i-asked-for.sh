#!/usr/bin/env bash
# actually-getting-what-i-asked-for.sh
#
# PreToolUse: mcp__plugin_playwright_playwright__browser_take_screenshot
#
# Blocks full-page screenshots of live URLs until a scroll video has been
# recorded since the last browser_navigate call.
# Because static screenshots on animated sites produce false reports.

STATE_DIR="$HOME/.command/hooks"
SCREENSHOTS_DIR="$HOME/.command/screenshots"
NAV_MARKER="$STATE_DIR/.last-navigate"

mkdir -p "$STATE_DIR" "$SCREENSHOTS_DIR"

# Read tool input JSON from stdin
INPUT=$(cat)

# Only enforce on fullPage=true — targeted element screenshots are fine
IS_FULL_PAGE=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('true' if d.get('fullPage') else 'false'" \
  2>/dev/null)

[[ "$IS_FULL_PAGE" != "true" ]] && exit 0

# If no navigate has happened this session, nothing to enforce
[[ ! -f "$NAV_MARKER" ]] && exit 0

# Check for a .webm newer than the last navigate call
RECENT_VIDEO=$(find "$SCREENSHOTS_DIR" -name "*.webm" -newer "$NAV_MARKER" 2>/dev/null | head -1)

if [[ -n "$RECENT_VIDEO" ]]; then
  exit 0
fi

# No video recorded since last navigate — block
cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║  BLOCKED — actually-getting-what-i-asked-for                    ║
║                                                                  ║
║  Full-page screenshot blocked. A scroll video is required        ║
║  before scoring any page with animations or scroll effects.      ║
║  Static screenshots produce false reports on animated sites.     ║
║                                                                  ║
║  Record the video first:                                         ║
║    node ~/.command/shortcuts/record-url.js "<url>" eyes-desktop  ║
║    node ~/.command/shortcuts/record-url.js "<url>" eyes-mobile --mobile
║                                                                  ║
║  Then extract frames:                                            ║
║    ffmpeg -i ~/.command/screenshots/eyes-desktop.webm \          ║
║      -vf fps=2 ~/.command/screenshots/frame_%03d.png             ║
║                                                                  ║
║  Read the frames. Then screenshot to confirm specific sections.  ║
╚══════════════════════════════════════════════════════════════════╝

EOF

exit 1
