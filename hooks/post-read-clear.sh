#!/bin/bash
# PostToolUse — Read
# When a PNG from /tmp/preview/ is Read:
#   1. Delete it immediately (space keeping)
#   2. Clear the visual-gate-pending flag
#   3. Purge any other stale preview files (>30 min)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

if echo "$FILE_PATH" | grep -qE '^/tmp/preview/.*\.png$'; then
  # Delete the PNG just Read
  rm -f "$FILE_PATH"

  # Clear the pending flag
  rm -f /tmp/visual-gate-pending

  # Purge old files (>30 min) — keep /tmp/preview/ lean
  find /tmp/preview -maxdepth 1 -name "*.png"  -mmin +30 -delete 2>/dev/null
  find /tmp/preview -maxdepth 1 -name "*.webm" -mmin +30 -delete 2>/dev/null
  find /tmp/preview -maxdepth 1 -name "*.mp4"  -mmin +30 -delete 2>/dev/null
  find /tmp/preview/frames -name "frame_*.png" -mmin +30 -delete 2>/dev/null
fi

exit 0
