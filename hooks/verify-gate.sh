#!/usr/bin/env bash
# Stop hook: block Claude Code from ending its turn after UI edits
# until a written verification note (latest.md) exists and passes.
#
# This is the SECOND stage of the two-stage gate system:
#   Stage 1 — stop-gate.sh:   screenshot taken and Read (clears /tmp/visual-gate-pending)
#   Stage 2 — this file:      verification note written, no FAILs, artifacts archived
#
# Uses project-relative .claude/verify/ so artifacts persist across sessions.
# Only activates when .claude/verify/.dirty exists (set by post-edit-mark-dirty.sh).

set -uo pipefail

DIRTY=.claude/verify/.dirty
NOTE=.claude/verify/latest.md

# Nothing visual was touched this session -> allow stop.
[ ! -f "$DIRTY" ] && exit 0

block() {
  echo "$1" >&2
  exit 2
}

# Note: stop_hook_active is intentionally NOT used as an early exit.
# This gate checks file existence — the .dirty flag and latest.md tell us
# definitively whether verification has happened. No budget counter needed.
INPUT=$(cat 2>/dev/null || echo "{}")

# Check verification note exists.
[ ! -f "$NOTE" ] && block "VISUAL GATE (verify): UI files were edited but no verification note exists.
Write .claude/verify/latest.md with a table of spec items checked:

| Spec item | Observed | Result |
|---|---|---|
| Layout / spacing | [what you saw] | PASS/FAIL |
| Colors / contrast | [what you saw] | PASS/FAIL |
| Typography | [what you saw] | PASS/FAIL |
| Mobile responsiveness | [what you saw] | PASS/FAIL |
| Animations / motion | [what you saw] | PASS/FAIL |

Compare against design/ spec if present. All items PASS before finishing."

# Note must be newer than the last edit.
if [ "$DIRTY" -nt "$NOTE" ]; then
  block "VISUAL GATE (verify): UI files changed after the last verification note.
Re-inspect the current screenshots, update .claude/verify/latest.md, then finish."
fi

# Note must not contain FAIL.
if grep -q "FAIL" "$NOTE" 2>/dev/null; then
  block "VISUAL GATE (verify): .claude/verify/latest.md contains FAIL items.
Fix the failing spec items and re-verify before finishing."
fi

# Gate passed: archive artifacts and clear dirty flag.
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p .claude/verify/history
[ -f ".claude/verify/latest.png" ] && cp ".claude/verify/latest.png" ".claude/verify/history/$TS.png" 2>/dev/null || true
cp "$NOTE" ".claude/verify/history/$TS.md" 2>/dev/null || true
rm -f "$DIRTY"
exit 0
