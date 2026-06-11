#!/usr/bin/env false
# Rule: Skill and Tool Invocation Order

---

## Iron Laws — Output-Time Check

**Iron Law 1 — Skill Before Reasoning:**
Observable check: Am I about to type a response to a task without invoking a skill/tool first?
Condition: YES → STOP → check skill list → invoke matching skill before any text output.
This does NOT override: the user explicitly saying "don't use a skill for this."

**Iron Law 2 — Tool Before Reasoning:**
Observable check: Does an MCP tool, bash command, or API call exist that gets real data?
Condition: YES → call the tool FIRST → use its output to reason.
This does NOT override: tasks that are purely conversational (no real-world state needed).

**Iron Law 3 — Never Reason First:**
If the thought is "let me think through how to do X" before checking for a skill — that's Layer 4.
Observable check: Did I invoke `Skill` tool or a real tool in this turn?
Condition: NO, and the task has a matching skill → STOP → invoke the skill NOW.

---

## Invocation Order (enforced)

```
1. Pre-action hooks (auto — cannot be skipped)
2. Skill tool (invoke matching skill before ANY response)
3. MCP / Bash / WebSearch / WebFetch (get real data before reasoning)
4. Reason from output of 1-3
5. NEVER: reason → then check if a skill exists
```

---

## Task → Skill Map (quick reference)

| Task contains | Invoke first |
|---|---|
| build website / new site / new page | `research-first` protocol + `landing-page-generator` |
| marketing plan / content plan | `content-strategy` |
| SEO / blog post / keywords | `seo-aeo-blog-writer` or `seo-keyword-strategist` |
| add photos / images | `seo-images` skill → then source photos |
| deploy / ship / push | check `deploy-gate.sh` output first |
| debug / fix bug | `systematic-debugging` or `investigate` |
| review code | `production-code-audit` |
| auth / login | `nextjs-supabase-auth` |
| animation / scroll | invoke `record.js` protocol via `visual-review-non-negotiable.md` |
| write copy | `copywriting` |
| competitor research | `competitor-profiling` |

---

## Rationalization Shield

| Thought | Reality | Correct action |
|---|---|---|
| "It's a simple task, I don't need a skill" | Simple tasks become complex. Skills prevent that. | Check the map above, invoke if match found |
| "I know how to do this already" | Skills encode tested patterns. Your memory doesn't. | Invoke the skill anyway |
| "The skill is overkill for this" | If the task type matches, the skill is exactly calibrated | Invoke, then adapt if needed |
| "I'll start and invoke later if needed" | "Later" means after you've already committed to a wrong approach | Invoke FIRST |
| "I need more context before invoking" | Skills tell you WHAT context to gather | Invoke, follow step 1 of the skill |

---

## How to Check

Before every response to a task request:
```bash
# Mental check (takes 3 seconds):
# 1. Does this task appear in the Task → Skill Map above? → invoke Skill
# 2. Does a skill exist for this category? → invoke Skill
# 3. Is there real-world data I should fetch first? → call the tool
# 4. ONLY THEN: reason and respond
```

Grade: **8.5/10** — output-time check (strong), but no pre-action hook to enforce it automatically.
Gap: Skills are not auto-matched to user intent by any hook. Trained behavior required.
