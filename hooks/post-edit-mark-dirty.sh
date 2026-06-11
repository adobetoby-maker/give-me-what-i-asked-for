#!/usr/bin/env bash
# PostToolUse hook: mark UI as "dirty" (needing visual verification)
# whenever Claude edits a watched source file.
# Receives hook JSON on stdin; extracts the edited file path.

set -euo pipefail

WATCHED_REGEX='(^|/)(src|app|components|pages|styles|ui)/|\.(css|scss|tsx|jsx|vue|svelte|swift|kt|xaml|html)$'

INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

[ -z "$FILE" ] && exit 0

if echo "$FILE" | grep -Eq "$WATCHED_REGEX"; then
  mkdir -p .claude/verify
  touch .claude/verify/.dirty
fi

# Track architecture-changing writes for claudemd-update-gate.sh (Stop hook)
# Fires when new routes, pages, layouts, or config files are created/modified
if echo "$FILE" | grep -Eq "(app/.*page\.(tsx|ts)|app/.*route\.(ts|tsx)|app/.*layout\.(tsx|ts)|next\.config\.(ts|js|mjs|cjs)|wrangler\.(json|jsonc)|vite\.config\.(ts|js)|tailwind\.config\.(ts|js))"; then
  echo "$(date +%s):$FILE" >> /tmp/arch-change-this-session
fi

exit 0
