#!/bin/bash
# Stop hook — CLAUDE.md Update Gate
# When architecture-changing files were written this session (tracked by /tmp/arch-change-this-session)
# and CLAUDE.md was NOT updated → inject a reminder before the turn ends.
# Rule: quality-gate.md Gate 6 + claude-md-rubric.md

FLAG="/tmp/arch-change-this-session"

[[ ! -f "$FLAG" ]] && exit 0

# Get the most recent arch change timestamp and file
LAST_CHANGE=$(tail -1 "$FLAG" 2>/dev/null)
CHANGE_TS=$(echo "$LAST_CHANGE" | cut -d: -f1)
CHANGE_FILE=$(echo "$LAST_CHANGE" | cut -d: -f2-)

[[ -z "$CHANGE_TS" ]] && exit 0

# Don't fire if the change was more than 2 hours ago (stale session)
NOW=$(date +%s)
(( NOW - CHANGE_TS > 7200 )) && rm -f "$FLAG" && exit 0

# Find the CLAUDE.md for this project by walking up from the changed file
CLAUDE_MD=""
SEARCH_DIR=$(dirname "$CHANGE_FILE")
for _ in 1 2 3 4 5 6; do
  [[ -z "$SEARCH_DIR" || "$SEARCH_DIR" == "/" ]] && break
  if [[ -f "$SEARCH_DIR/CLAUDE.md" ]]; then
    CLAUDE_MD="$SEARCH_DIR/CLAUDE.md"
    break
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

[[ -z "$CLAUDE_MD" ]] && exit 0

# Check if CLAUDE.md was modified more recently than the arch change
CLAUDE_MTIME=$(stat -f "%m" "$CLAUDE_MD" 2>/dev/null || echo 0)

if (( CLAUDE_MTIME > CHANGE_TS )); then
  # CLAUDE.md is newer — gate passes, clear flag
  rm -f "$FLAG"
  exit 0
fi

# Collect all changed files from flag
CHANGED_FILES=$(cat "$FLAG" 2>/dev/null | cut -d: -f2- | \
  while read -r f; do basename "$f"; done | sort -u | head -5 | paste -sd ', ')

python3 - "$CLAUDE_MD" "$CHANGED_FILES" << 'PYEOF'
import sys, json

claude_md    = sys.argv[1]
files        = sys.argv[2]

context = f"""CLAUDE.md UPDATE GATE — quality-gate.md Gate 6
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Architecture-changing files written this session: {files}
{claude_md} has NOT been updated since those changes.

Gate 6 fires when any of these are added:
  □ New routes or pages    → update Architecture section
  □ New dependencies       → update Commands or Stack section
  □ New environment vars   → update Env Vars (names only, no values)
  □ New failure patterns   → update Failure Patterns section

Claude-md rubric checks (run before finishing):
  wc -l {claude_md}        # must be 150–300 lines
  grep -c "^| " {claude_md} # must be ≥5 decision rows

Minimum viable update: add one row to Failure Patterns if nothing else changed.
Clear this gate: edit {claude_md} and the flag clears at next Stop.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"""

print(json.dumps({"additionalContext": context}))
PYEOF
