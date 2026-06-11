#!/bin/bash
# PreToolUse hook — Write tool — Research Gate
# Fires before writing code files.
#
# Hard block cases:
#   1. New project (no commits) + no scores.md → always block
#   2. Existing project + no scores.md + writing a NEW page/route file → block
#
# Warning only:
#   3. Existing project + no scores.md + editing existing file → warn but allow
#
# Rule: research-first.md Iron Law

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only check source code files
if ! echo "$FILE_PATH" | grep -qE '\.(tsx|ts|jsx|js|css|scss|html)$'; then
  exit 0
fi

# Skip rule/config/memory files
if echo "$FILE_PATH" | grep -qE '(\.claude|node_modules|\.git|hooks\.json|settings\.json|SKILL\.md|CLAUDE\.md|scores\.md)'; then
  exit 0
fi

# Walk up to find the project root (directory with package.json)
PROJECT_ROOT=""
DIR=$(dirname "$FILE_PATH")
DEPTH=0
while [ "$DIR" != "/" ] && [ -n "$DIR" ] && [ "$DEPTH" -lt 8 ]; do
  if [ -f "$DIR/package.json" ]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
  DEPTH=$((DEPTH + 1))
done

[ -z "$PROJECT_ROOT" ] && exit 0

# scores.md present → research done → proceed
[ -f "$PROJECT_ROOT/scores.md" ] && exit 0

# scores.md missing — determine response level
HAS_COMMITS=$(cd "$PROJECT_ROOT" 2>/dev/null && git log --oneline -1 2>/dev/null | wc -l | tr -d ' ' || echo "0")

# ── Case 1: New project, no commits → hard stop ──────────────────────────────
if [ "$HAS_COMMITS" = "0" ]; then
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║  ⛔ RESEARCH GATE — NEW PROJECT — research-first.md        ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Project: $PROJECT_ROOT"
  echo "  scores.md: MISSING | Git commits: NONE"
  echo ""
  echo "  Iron Law: No code written until scores.md exists."
  echo ""
  echo "  Research protocol:"
  echo "  1. WebSearch: 'best [category] websites 2026' → 3 references"
  echo "  2. Screenshot each: node ~/screenshot.js <port>"
  echo "  3. Score on: hero, typography, CTA, mobile, trust, speed"
  echo "  4. Write scores.md: 'Build better than X on [dimensions]'"
  echo ""
  echo "  Exception: targeted bug fix on known file → state it explicitly"
  exit 2
fi

# ── Case 2: Has commits + no scores.md + writing a NEW page/route ────────────
# A new page file that doesn't exist yet = new feature build = research required
IS_NEW_PAGE=false
if ! [ -f "$FILE_PATH" ]; then
  BASENAME=$(basename "$FILE_PATH")
  if echo "$BASENAME" | grep -qE "^(page|route|layout|index)\.(tsx|ts|jsx|js)$"; then
    IS_NEW_PAGE=true
  fi
fi

if [ "$IS_NEW_PAGE" = "true" ]; then
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║  ⛔ RESEARCH GATE — NEW PAGE WITHOUT scores.md             ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Writing new page: $FILE_PATH"
  echo "  scores.md: MISSING"
  echo ""
  echo "  New pages compete. Research required before building."
  echo ""
  echo "  Quick path:"
  echo "  WebSearch 2-3 competitors → score them → write scores.md"
  echo "  scores.md can be 5 lines. The gate clears when it exists."
  echo ""
  echo "  Exception: this page was explicitly spec'd — state that and"
  echo "  write scores.md as a placeholder, then proceed."
  exit 2
fi

# ── Case 3: Has commits + no scores.md + editing existing files → warn ───────
PAGE_COUNT=$(find "$PROJECT_ROOT/app" "$PROJECT_ROOT/src" -name "page.tsx" -o -name "index.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PAGE_COUNT" = "0" ]; then
  echo "RESEARCH WARNING: $PROJECT_ROOT has commits but no pages and no scores.md."
  echo "If building new pages → run research protocol first."
  echo "If bug fixing → proceed (and state that explicitly)."
fi
