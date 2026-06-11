#!/bin/bash
# slip-proof audit.sh
# Maps every Iron Law in ~/.claude/rules/ to its hook coverage.
# Outputs three sections: IRON LAWS, HOOK COVERAGE, GAPS
# Usage: bash ~/.claude/skills/slip-proof/scripts/audit.sh

RULES_DIR="$HOME/.claude/rules"
HOOKS_FILE="$HOME/.claude/hooks.json"
HOOKS_DIR="$HOME/.claude/hooks"

RESET='\033[0m'
BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  SLIP-PROOF AUDIT — Enforcement Gap Analysis${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ── Section 1: Iron Laws per rule file ────────────────────────────────────────
echo -e "${CYAN}SECTION 1 — IRON LAWS PER RULE FILE${RESET}"
echo -e "${CYAN}─────────────────────────────────────${RESET}"

for f in "$RULES_DIR"/*.md; do
  NAME=$(basename "$f" .md)
  LAW_COUNT=$(grep -c "Iron Law" "$f" 2>/dev/null || echo 0)
  echo "RULE: $NAME"
  echo "  Iron Laws: $LAW_COUNT"
  # Show first line of each Iron Law
  grep -n "Iron Law" "$f" 2>/dev/null | head -4 | while read -r line; do
    echo "    $line"
  done
  echo "---"
done

echo ""

# ── Section 2: Hook coverage ──────────────────────────────────────────────────
echo -e "${CYAN}SECTION 2 — REGISTERED HOOKS${RESET}"
echo -e "${CYAN}────────────────────────────${RESET}"

python3 - "$HOOKS_FILE" << 'PYEOF'
import json, os, sys

hooks_file = sys.argv[1]
try:
    with open(hooks_file) as f:
        d = json.load(f)
except Exception as e:
    print(f"ERROR reading hooks.json: {e}")
    sys.exit(1)

hooks = d.get('hooks', {})
total = 0
for event, entries in hooks.items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            script = os.path.basename(cmd.split()[-1]) if cmd else cmd
            matcher = entry.get('matcher', 'ALL')
            async_flag = ' (async)' if hook.get('async') else ''
            print(f"  {event} [{matcher}] → {script}{async_flag}")
            total += 1

print(f"\n  Total hooks registered: {total}")
PYEOF

echo ""

# ── Section 3: Gap analysis ────────────────────────────────────────────────────
echo -e "${CYAN}SECTION 3 — COVERAGE GAPS (rules with weak or no hooks)${RESET}"
echo -e "${CYAN}─────────────────────────────────────────────────────────${RESET}"

python3 - "$RULES_DIR" "$HOOKS_DIR" "$HOOKS_FILE" << 'PYEOF'
import os, sys, re, json

rules_dir = sys.argv[1]
hooks_dir = sys.argv[2]
hooks_file = sys.argv[3]

# Read all hook scripts content
hook_content = {}
for f in os.listdir(hooks_dir):
    if f.endswith('.sh'):
        try:
            hook_content[f] = open(os.path.join(hooks_dir, f)).read().lower()
        except:
            pass

# Read hooks.json for registered hooks
try:
    registered = json.load(open(hooks_file))
except:
    registered = {}

# Known hook associations (rule name → hook files that cover it)
COVERAGE_MAP = {
    'visual-review-non-negotiable': ['visual-gate.sh', 'eyes-precheck.sh', 'stop-gate.sh', 'verify-gate.sh', 'message-display-gate.sh'],
    'eyes-always': ['visual-gate.sh', 'eyes-precheck.sh', 'stop-gate.sh'],
    'research-first': ['research-gate.sh'],
    'core-four': ['scope-check.sh', 'stop-gate.sh', 'message-display-gate.sh'],
    'quality-gate': ['code-gate.sh', 'deploy-gate.sh', 'visual-gate.sh', 'verify-gate.sh', 'claudemd-update-gate.sh'],
    'skill-invocation-order': ['prompt-gate.sh', 'skill-skip-gate.sh'],
    'skill-self-selection': ['prompt-gate.sh'],
    'autonomous-operations': ['message-display-gate.sh', 'api-wall-flag.sh'],
    'api-wall-checklist': ['api-wall-flag.sh'],
    'no-asterisks-in-urls-or-paths': ['message-display-gate.sh'],
    'client-handoff-protocol': ['deploy-gate.sh'],
    'demo-to-live-protocol': ['deploy-gate.sh'],
    'claude-md-rubric': ['claudemd-update-gate.sh'],
    'kaizen-7-steps': [],
    'image-sourcing-protocol': [],
    'md-architecture': [],
}

# Bypass mode assignments (rule → primary bypass mode #)
BYPASS_MODES = {
    'visual-review-non-negotiable': '1+2 (reasoning + speed pressure) → FIXED',
    'eyes-always': '1+2 → FIXED',
    'research-first': '1+2 → FIXED (new projects) / 2 (continuing) → IMPROVED',
    'core-four': '3 (silent assumption) → Rule3 FIXED / Rule2 IMPROVED',
    'quality-gate': '4 (no observable trigger) → PARTIAL — SEO Gate 3 still text-only',
    'skill-invocation-order': '1 (reasoning-time skip) → IMPROVED (skill-skip-gate)',
    'skill-self-selection': '1 → PARTIAL (prompt-gate injects, not blocks)',
    'autonomous-operations': '3+5 → FIXED (stuck-reporter in MessageDisplay)',
    'api-wall-checklist': '5 (terminal-only output) → FIXED (api-wall-flag)',
    'no-asterisks-in-urls-or-paths': '5 (output-time) → FIXED (asterisk-stripper)',
    'client-handoff-protocol': '4 (no trigger) → FIXED ([DEMO] deploy block)',
    'demo-to-live-protocol': '4 → FIXED ([DEMO] deploy block)',
    'claude-md-rubric': '4 → FIXED (claudemd-update-gate)',
    'kaizen-7-steps': '1 (reasoning-time) → UNHOOKABLE — process skill, not an observable trigger',
    'image-sourcing-protocol': '3+5 → TEXT-ONLY — no hook exists',
    'md-architecture': '1 → TEXT-ONLY — meta rule, no observable state',
}

GRADE_MAP = {
    'visual-review-non-negotiable': '9/10',
    'eyes-always': '9/10',
    'research-first': '8/10',
    'core-four': '8/10',
    'quality-gate': '7/10',
    'skill-invocation-order': '7/10',
    'skill-self-selection': '7/10',
    'autonomous-operations': '8/10',
    'api-wall-checklist': '7/10',
    'no-asterisks-in-urls-or-paths': '8/10',
    'client-handoff-protocol': '8/10',
    'demo-to-live-protocol': '8/10',
    'claude-md-rubric': '7/10',
    'kaizen-7-steps': '4/10 (unhookable — process skill)',
    'image-sourcing-protocol': '5/10 (text-only — needs hook)',
    'md-architecture': '4/10 (meta rule — needs hook)',
}

NEEDS_HOOK = {
    'kaizen-7-steps': False,  # Process skill — cannot be meaningfully hooked
    'image-sourcing-protocol': True,  # Needs: PreToolUse:Bash for curl/cp image commands
    'md-architecture': False,  # Meta rule — governs how rules are written, not runtime behavior
}

print("\n  RULE                              GRADE    BYPASS MODE(S)")
print("  " + "─" * 78)

for f in sorted(os.listdir(rules_dir)):
    if not f.endswith('.md'):
        continue
    name = f[:-3]
    hooks_list = COVERAGE_MAP.get(name, None)
    grade = GRADE_MAP.get(name, '?/10')
    bypass = BYPASS_MODES.get(name, 'unknown — run manual analysis')

    if hooks_list is None:
        status = '⚠ UNMAPPED'
        color = '\033[33m'  # yellow
    elif not hooks_list:
        if NEEDS_HOOK.get(name, True):
            status = '✗ TEXT-ONLY'
            color = '\033[31m'  # red
        else:
            status = '○ UNHOOKABLE'
            color = '\033[33m'  # yellow
    else:
        status = '✓ HOOKED'
        color = '\033[32m'  # green

    reset = '\033[0m'
    print(f"  {color}{name:<35}{reset} {grade:<9} {bypass[:45]}")
    if status in ('✗ TEXT-ONLY', '⚠ UNMAPPED'):
        print(f"    {color}→ {status}{reset}")
        if name == 'image-sourcing-protocol':
            print(f"      Recommended: PreToolUse:Bash — detect curl/cp of image files")
            print(f"      When: command matches (curl.*pexels|unsplash|cp.*jpg|png)")
            print(f"      Fire: inject ownership-check reminder (Iron Law 1)")

print("\n  LEGEND: ✓ hooked  ○ unhookable (process skill)  ✗ text-only (needs hook)")
PYEOF

echo ""
echo -e "${CYAN}SECTION 4 — HOOKS.JSON VALIDATION${RESET}"
echo -e "${CYAN}──────────────────────────────────${RESET}"
if python3 -m json.tool "$HOOKS_FILE" > /dev/null 2>&1; then
  echo -e "  ${GREEN}hooks.json: valid JSON ✓${RESET}"
else
  echo -e "  ${RED}hooks.json: INVALID JSON — fix before next session${RESET}"
  python3 -m json.tool "$HOOKS_FILE" 2>&1 | head -5
fi

echo ""
echo -e "${CYAN}SECTION 5 — HOOK SCRIPT PERMISSIONS${RESET}"
echo -e "${CYAN}─────────────────────────────────────${RESET}"
NOT_EXEC=0
for f in "$HOOKS_DIR"/*.sh; do
  if [ ! -x "$f" ]; then
    echo -e "  ${YELLOW}NOT EXECUTABLE: $(basename $f)${RESET} — run: chmod +x $f"
    NOT_EXEC=$((NOT_EXEC + 1))
  fi
done
if [ "$NOT_EXEC" = "0" ]; then
  echo -e "  ${GREEN}All hook scripts are executable ✓${RESET}"
fi

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  Audit complete. Run /slip-proof apply <rule-name> to close gaps.${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
