#!/bin/bash
# Stop hook — Skill Skip Gate
# If prompt-gate armed /tmp/skill-required-this-turn and PostToolUse:Skill did NOT clear it,
# the required skill was skipped this turn. Inject a correction into the next turn.
# Rule: skill-invocation-order.md Iron Law 1

FLAG="/tmp/skill-required-this-turn"

[[ ! -f "$FLAG" ]] && exit 0

ENTRY=$(cat "$FLAG" 2>/dev/null)
TS=$(echo "$ENTRY" | cut -d: -f1)
SKILL=$(echo "$ENTRY" | cut -d: -f2-)

[[ -z "$TS" || -z "$SKILL" ]] && exit 0

NOW=$(date +%s)
# Only fire if recent — same turn window
(( NOW - TS > 600 )) && rm -f "$FLAG" && exit 0

# Clear the flag — inject once, don't repeat next turn unless re-triggered
rm -f "$FLAG"

python3 - "$SKILL" << 'PYEOF'
import sys, json

skill = sys.argv[1]

context = f"""SKILL INVOCATION SKIPPED — skill-invocation-order.md Iron Law 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This turn required: Skill({{"skill": "{skill}"}})
The Skill tool was NOT invoked before responding.

Why this matters:
  Skills encode tested patterns refined over real sessions.
  Reasoning from general knowledge bypasses those patterns.
  "I know how to do this" is the rationalization that iter-16 came from.

REQUIRED ACTION for the next response — before ANY other tool call:
  1. Invoke Skill({{"skill": "{skill}"}})
  2. Read the skill instructions completely
  3. Follow the skill's Step 1 before writing any code or explanation

Rationalizations to reject:
  "I already know this" → skills evolve; yours is stale
  "The skill is overkill" → if the task matches, the skill is calibrated
  "I already started" → restart from the skill's step 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"""

print(json.dumps({"additionalContext": context}))
PYEOF
