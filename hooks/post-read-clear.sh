#!/bin/bash
# PostToolUse — Read
# Clears the visual-gate-pending flag when the model Reads a PNG from /tmp/preview/.
# This is the "acknowledgment" that closes the eyes-precheck.sh gate.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only clear if reading a PNG from the preview directory
if echo "$FILE_PATH" | grep -qE '^/tmp/preview/.*\.png$'; then
  rm -f /tmp/visual-gate-pending
fi

exit 0
