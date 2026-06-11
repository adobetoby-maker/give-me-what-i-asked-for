#!/bin/bash
# PreToolUse — Write | Edit
# Core Rule 3: Only touch the files you were asked about.
# Injects a scope-confirmation reminder before every file write.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    print(inp.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

[[ -z "$FILE_PATH" ]] && exit 0

# Extract just the filename for the message
BASENAME=$(basename "$FILE_PATH")

python3 - "$FILE_PATH" "$BASENAME" << 'PYEOF'
import sys, json

file_path = sys.argv[1]
basename  = sys.argv[2]

context = f"""┌─────────────────────────────────────────────────────────────┐
│  CORE RULE 3 — SCOPE CHECK                                 │
│  About to write: {basename:<43}│
│                                                             │
│  Was this file explicitly asked about by the user?         │
│  If NO — state why this file is in scope before writing.   │
│  If out of scope — stop and ask first.                     │
└─────────────────────────────────────────────────────────────┘"""

print(json.dumps({"additionalContext": context}))
PYEOF
