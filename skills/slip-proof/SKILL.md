---
name: slip-proof
version: 2.0.0
description: |
  Audits every rule file in ~/.claude/rules/ against the 7 bypass modes and
  the 10 hook event types. Identifies rules that are text-only (no structural
  enforcement) and generates hook code to close each gap.
  Trigger: /slip-proof
triggers:
  - /slip-proof
  - slip-proof audit
  - slip-proof apply
  - find rules without hooks
  - what rules aren't enforced
  - gate audit
  - hook audit
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# slip-proof — Enforcement Gap Auditor

When invoked, this skill finds every rule that can be bypassed and closes the gap with a hook.

---

## The 7 Bypass Modes

Every enforcement failure traces back to one of these. Know which mode a rule suffers from
before deciding which hook type to apply:

| # | Mode | Description | Tells you |
|---|---|---|---|
| 1 | Reasoning-time override | Rule only fires when model chooses to apply it | Needs PreToolUse or UserPromptSubmit hook |
| 2 | Speed pressure | Rule skipped under "quick fix" framing | Needs observable state check, not intent check |
| 3 | Silent assumption | Model picks a file/approach without stating it | Needs scope-check hook on Write/Edit |
| 4 | No observable trigger | Rule has no bash check — purely aspirational | Needs flag file + hook that checks it |
| 5 | Terminal-only output | Hook echoes to terminal; model never sees it | Fix: return `{"additionalContext":"..."}` JSON |
| 6 | Done-in-text structural gap | Model writes "done" as plain text with no tool call | Needs Stop hook with `decision:block` |
| 7 | Gate-check ritual bypass | Model runs `ls /tmp/visual-gate-pending` to "check" | Block that exact bash pattern in eyes-precheck.sh |

---

## The 10 Hook Event Types

| Event | When it fires | Best for |
|---|---|---|
| `UserPromptSubmit` | Before model processes any message | Skill injection, files-first gate, pending-flag checks |
| `SessionStart` | Once when session opens | Memory sync, bootstrap, context injection |
| `PreToolUse:Write` | Before any file write | Research gate, scope check, Rule 2 abstraction block |
| `PreToolUse:Edit` | Before any file edit | Same as Write |
| `PreToolUse:Bash` | Before any bash command | Deploy gate, DEMO check, visual block, code gate |
| `PreToolUse:Skill` | Before skill tool call | Clear required-skill flag (not usually needed) |
| `PostToolUse:Read` | After any file read | Clear visual-gate-pending (screenshot was read) |
| `PostToolUse:Write\|Edit` | After any write/edit | Take screenshot, mark dirty, track arch changes |
| `PostToolUse:Bash` | After any bash command | API wall detection, build-eyes, commit security scan |
| `Stop` | When turn ends | Block premature done, verify-gate, skill-skip, CLAUDE.md update |
| `MessageDisplay` | As message renders | Asterisk stripper, stuck-reporter, gate-violation branding |

---

## How to Run This Skill

### Step 1 — Run the audit script

```bash
bash ~/.claude/skills/slip-proof/scripts/audit.sh
```

Read the output carefully. It produces three sections:
- `IRON LAWS` — every Iron Law found in every rule file
- `HOOK COVERAGE` — every hook currently registered with its event + matcher
- `GAPS` — rules with no matching hook, plus their current enforcement grade

### Step 2 — Classify each gap by bypass mode

For each rule in the GAPS section:
1. Read the rule file: `cat ~/.claude/rules/<name>.md`
2. Identify which of the 7 bypass modes it suffers from
3. Identify which hook event type would close it (see table above)

### Step 3 — Score each rule

Grade each rule file on a 10-point enforcement scale:

| Score | Mechanism | Description |
|---|---|---|
| 9–10 | PreToolUse/Stop exit 2 | Hard block — tool call never happens |
| 8–9 | PostToolUse inject + Stop block | Observable state + turn-end block |
| 7–8 | UserPromptSubmit additionalContext | Strong injection, model can still rationalize |
| 5–6 | reasoning-time injection | Injected but no structural catch |
| 3–4 | text-in-rule-file only | Model must choose to apply it |
| 1–2 | aspirational language | "should", "must", "always" with no trigger |

### Step 4 — Generate hook code for each gap

For each gap, write the hook following this pattern:

```bash
#!/bin/bash
# <event>:<matcher> — <Rule Name> Gate
# Fires: <when>
# Closes: bypass mode <N> (<mode name>)
# Rule: <rule-file>.md

INPUT=$(cat)

# ── Observable state check ────────────────────────────────────────────────────
<BASH_CHECK_THAT_EXITS_0_WHEN_GATE_SHOULD_FIRE>
# Exit 0 = proceed. Exit 2 = block.

# ── Injection ─────────────────────────────────────────────────────────────────
python3 << 'PYEOF'
import json
context = """<RULE_NAME> GATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<What was detected and why it matters>
<Required action>
<How to clear the gate>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"""
# Use additionalContext for injection (model sees it)
# Use decision:block for hard stops (Write/Edit blocked)
print(json.dumps({"additionalContext": context}))
PYEOF
```

### Step 5 — Register in hooks.json

```json
{
  "matcher": "<ToolName>",
  "hooks": [{
    "type": "command",
    "command": "bash /Users/drive/.claude/hooks/<new-hook>.sh",
    "timeout": 10
  }]
}
```

For async hooks (non-blocking, just tracking):
```json
{
  "type": "command",
  "command": "bash /Users/drive/.claude/hooks/<new-hook>.sh",
  "timeout": 5,
  "async": true
}
```

### Step 6 — Verify the hook fires

```bash
# Test hook output directly:
echo '{"tool_input":{"file_path":"/test/page.tsx"},"cwd":"/test"}' | bash ~/.claude/hooks/<hook>.sh

# Verify it produces valid JSON:
echo '{}' | bash ~/.claude/hooks/<hook>.sh | python3 -c "import json,sys; print(json.load(sys.stdin))"

# Check hooks.json is valid:
python3 -m json.tool ~/.claude/hooks.json > /dev/null && echo "JSON valid"
```

### Step 7 — Update the give-me-what-i-asked-for repo

After adding or improving any hook:
```bash
cd /Users/drive/give-me-what-i-asked-for
# Update README.md with the new hook in the 10-hook table
# Update SCHEMA.md if a new bypass mode or hook pattern was discovered
git add -A
git commit -m "slip-proof: add <hook-name> for <rule-name> (bypass mode <N>)"
git push
```

---

## Current Hook Inventory (as of 2026-06-11)

Run `bash ~/.claude/skills/slip-proof/scripts/audit.sh` for live state.

| Hook | Event | Closes |
|---|---|---|
| `visual-gate.sh` | PostToolUse:Write\|Edit | Visual bypass mode 1+2+4 |
| `post-edit-mark-dirty.sh` | PostToolUse:Write\|Edit (async) | Visual verify gate |
| `eyes-precheck.sh` | PreToolUse:Write\|Edit\|Bash | Visual bypass mode 6+7 |
| `post-read-clear.sh` | PostToolUse:Read | Clears visual gate when PNG read |
| `stop-gate.sh` | Stop | Visual bypass mode 6 (done-in-text) |
| `verify-gate.sh` | Stop | Project verify note requirement |
| `message-display-gate.sh` | MessageDisplay | Mode 5 visual + asterisk + stuck-reporter |
| `prompt-gate.sh` | UserPromptSubmit | Skill injection + files-first + core 4 |
| `research-gate.sh` | PreToolUse:Write | Research bypass mode 1+2 |
| `scope-check.sh` | PreToolUse:Write\|Edit | Rule 3 scope + Rule 2 abstraction (mode 3) |
| `deploy-gate.sh` | PreToolUse:Bash | DEMO check + platform gate + SEO flag |
| `code-gate.sh` | PreToolUse:Bash | TypeScript gate before deploy |
| `visual-block.sh` | PreToolUse:Bash | Blocks git commit while visual gate armed |
| `commit-gate.sh` | PostToolUse:Bash | Security scan after git commit |
| `build-eyes.sh` | PostToolUse:Bash | Screenshots after build/dev server |
| `api-wall-flag.sh` | PostToolUse:Bash | Auth wall detection (mode 5) |
| `claudemd-update-gate.sh` | Stop | Gate 6 CLAUDE.md update requirement |
| `skill-skip-gate.sh` | Stop | Skill invocation verification |

---

## Exit Criteria

This skill is complete when:
- [ ] `audit.sh` output shows no rule with grade < 6/10 (unless documented as unhookable)
- [ ] Every new hook returns valid JSON (tested with `echo '{}' | bash hook.sh`)
- [ ] `hooks.json` passes `python3 -m json.tool` with no errors
- [ ] `give-me-what-i-asked-for` README updated with new hooks
- [ ] `git push` confirmed on the give-me-what-i-asked-for repo
