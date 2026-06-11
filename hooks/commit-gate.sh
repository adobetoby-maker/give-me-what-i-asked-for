#!/bin/bash
# ~/.claude/hooks/commit-gate.sh
# PostToolUse:Bash — fires after git commit
# Runs 3 security checks on the committed diff
# Reports HIGH findings immediately

INPUT=$(cat)

# Only fire on successful git commit commands
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

if ! echo "$COMMAND" | grep -qE "^git commit"; then
  exit 0
fi

# Change into the repo directory from the hook input context
REPO_DIR=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('cwd', ''))
except:
    print('')
" 2>/dev/null)

[ -n "$REPO_DIR" ] && cd "$REPO_DIR" 2>/dev/null || true

# Get changed files from last commit
CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | head -20)
if [ -z "$CHANGED" ]; then
  exit 0
fi

FINDINGS=""

# ── Check 1: Hardcoded secrets ────────────────────────────────────────────
CHECK1=$(git diff HEAD~1 HEAD 2>/dev/null | grep "^+" | \
  grep -iE "(api_key|secret|password|token|sk_live|sk_test|Bearer [A-Za-z0-9]{20,})" | \
  grep -vE "^(\+\+\+|#|//|\*)" | \
  grep -vE "(env|process\.env|os\.environ|\$\{|\$[A-Z_]+)" | \
  head -5)

if [ -n "$CHECK1" ]; then
  FINDINGS="$FINDINGS\n⛔ HIGH: Possible hardcoded secret in diff:\n$CHECK1"
fi

# ── Check 2: New exec/spawn without arg array ──────────────────────────────
CHECK2=$(git diff HEAD~1 HEAD 2>/dev/null | grep "^+" | \
  grep -E "(exec\`|exec\([\`']|execSync\([\`']|child_process\.exec\([\`'])" | \
  grep -vE "execFile|spawnSync|spawn\(" | \
  head -5)

if [ -n "$CHECK2" ]; then
  FINDINGS="$FINDINGS\n🟡 MEDIUM: Shell-interpolated exec (injection risk):\n$CHECK2"
fi

# ── Check 3: Service role key in 'use client' files ───────────────────────
CHECK3_FILES=""
while IFS= read -r changed_file; do
  if git show HEAD:"$changed_file" 2>/dev/null | grep -q "'use client'"; then
    if git diff HEAD~1 HEAD -- "$changed_file" 2>/dev/null | grep "^+" | \
        grep -qE "(supabaseAdmin|service_role|SUPABASE_SERVICE_ROLE)"; then
      CHECK3_FILES="$CHECK3_FILES  $changed_file\n"
    fi
  fi
done <<< "$CHANGED"

if [ -n "$CHECK3_FILES" ]; then
  FINDINGS="$FINDINGS\n⛔ HIGH: Service role import in 'use client' file:\n$CHECK3_FILES"
fi

# ── Report ────────────────────────────────────────────────────────────────
if [ -n "$FINDINGS" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  🔐 COMMIT SECURITY SCAN                                 ║"
  echo "╠══════════════════════════════════════════════════════════╣"
  printf '%b\n' "$FINDINGS" | while IFS= read -r line; do
    printf "║  %-56s║\n" "$line"
  done
  echo "╠══════════════════════════════════════════════════════════╣"
  echo "║  Review before pushing. HIGH = do not push.             ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
else
  echo "  🔐 Security scan: clean (no secrets, no shell exec, no client leaks)"
fi
