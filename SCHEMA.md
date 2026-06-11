# Give Me What I Asked For — Execution Schema

**Purpose:** Session-injectable reference. Paste into context or load at SessionStart to
give any model a complete operational map of this enforcement architecture.

---

## The Core Invariant

```
No visual file change is ever "done" without pixel evidence.
```

Everything else in this system is a mechanism to enforce that one invariant across every
possible bypass route.

---

## Full Task Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TASK EXECUTION LIFECYCLE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  USER SUBMITS MESSAGE                                                       │
│       │                                                                     │
│       ▼  [UserPromptSubmit hook]                                            │
│  prompt-gate.sh                                                             │
│    • Inject Core 4 Rules + HONESTY block into reasoning context             │
│    • If /tmp/skipped-gate exists → NUCLEAR INJECTION (gate violated         │
│      last turn) → force Read of unread PNGs before processing message       │
│    • If /tmp/visual-gate-pending fresh → warn: "unread screenshots exist"   │
│    • If /tmp/visual-server-needed fresh → warn: "server was down last edit" │
│    • Route task type → matching skill (19 patterns)                         │
│    • FILES-FIRST gate: check local dirs before WebSearch                    │
│       │                                                                     │
│       ▼                                                                     │
│  MODEL RECEIVES TASK + INJECTED CONTEXT                                     │
│       │                                                                     │
│       ├──────────────────────────────────────────────────────────────────►  │
│       │   New project / no scores.md?                                       │
│       │   [PreToolUse Write — research-gate.sh]                             │
│       │   → BLOCK until research runs + scores.md written                  │
│       │                                                                     │
│       ▼                                                                     │
│  MODEL WRITES / EDITS FILES                                                 │
│       │                                                                     │
│       ├── [PreToolUse Write|Edit — eyes-precheck.sh]                        │
│       │       Gate 1: /tmp/visual-gate-pending fresh?                       │
│       │         YES → EXIT 2 BLOCK: "Read these PNGs first"                │
│       │               Lists exact PNG paths. No write until Read.           │
│       │       Gate 2: /tmp/visual-server-needed fresh?                      │
│       │         YES → EXIT 2 BLOCK: "Start dev server first"               │
│       │               Vercel fallback PNGs listed if available.             │
│       │                                                                     │
│       ├── [PreToolUse Write|Edit — scope-check.sh]                          │
│       │       Inject: "Is this file explicitly in scope? If not, state why" │
│       │                                                                     │
│       ▼  (write/edit proceeds if gates clear)                               │
│  FILE WRITTEN                                                               │
│       │                                                                     │
│       ├── [PostToolUse Write|Edit — post-edit-mark-dirty.sh]               │
│       │       Touch .claude/verify/.dirty (arms verify-gate.sh)             │
│       │                                                                     │
│       └── [PostToolUse Write|Edit — visual-gate.sh]  (timeout: 120s)       │
│               Is this a visual file? (.tsx .css .svg .png .html .glsl...)   │
│               YES:                                                           │
│                 → screenshot localhost (if server found)                    │
│                 → screenshot Vercel URL (if .vercelurl — ALWAYS)            │
│                 → if animation/3D detected: record.js + ffmpeg frames       │
│                 → write /tmp/visual-gate-pending (arms PreToolUse gate)     │
│                 → if no server: write /tmp/visual-server-needed             │
│                 → inject PNG + frame paths into additionalContext            │
│               NO:                                                            │
│                 → exit 0 (non-visual file, no gate armed)                   │
│                                                                             │
│       ▼                                                                     │
│  MODEL READS SCREENSHOTS                                                    │
│       │                                                                     │
│       │   [PostToolUse Read — post-read-clear.sh]                           │
│       │       File is /tmp/preview/*.png?                                   │
│       │         YES → delete PNG immediately (space keeping)               │
│       │               rm /tmp/visual-gate-pending                           │
│       │               rm /tmp/visual-server-needed                          │
│       │               rm /tmp/stop-gate-blocks  (reset block budget)        │
│       │               rm /tmp/skipped-gate                                  │
│       │               purge /tmp/preview/ files > 30 min                   │
│       │               → GATE CLEARED                                        │
│       │                                                                     │
│       ▼                                                                     │
│  MODEL WRITES VERIFICATION NOTE                                             │
│       │                                                                     │
│       │   Write .claude/verify/latest.md:                                  │
│       │   | Spec item     | Observed                  | Result |            │
│       │   | Layout        | [what pixels showed]      | PASS   |            │
│       │   | Colors        | [what pixels showed]      | PASS   |            │
│       │   | Typography    | [what pixels showed]      | PASS   |            │
│       │   | Mobile 375px  | [what pixels showed]      | PASS   |            │
│       │   | Animations    | [what video frames showed]| PASS   |            │
│       │                                                                     │
│       ▼                                                                     │
│  MODEL DECLARES DONE                                                        │
│       │                                                                     │
│       ├── [MessageDisplay — message-display-gate.sh]                        │
│       │       "done/complete/finished/shipped" in text?                     │
│       │       + gate still armed?                                           │
│       │         → append GATE VIOLATION warning to rendered message         │
│       │         → write /tmp/skipped-gate                                   │
│       │                                                                     │
│       └── [Stop hook — stop-gate.sh + verify-gate.sh]                      │
│               STOP-GATE: /tmp/visual-gate-pending fresh?                    │
│                 YES → {"decision":"block"} — turn CANNOT end               │
│                       inject: "Read these PNGs: [paths]"                   │
│                       increment /tmp/stop-gate-blocks                       │
│                       write /tmp/skipped-gate as backstop                   │
│                       Budget: 3 blocks max (then next-turn injection)       │
│               VERIFY-GATE: .claude/verify/.dirty exists?                   │
│                 YES → block until .claude/verify/latest.md written         │
│                        + newer than last edit                               │
│                        + contains no FAIL entries                           │
│                                                                             │
│       ▼  (both gates clear)                                                 │
│  DONE — ACTUALLY                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Flag File State Machine

```
EVENT                              FLAG WRITTEN              FLAG CLEARED BY
─────────────────────────────────  ───────────────────────   ──────────────────────────────
visual file edited, server up      /tmp/visual-gate-pending  post-read-clear.sh (PNG Read)
visual file edited, no server      /tmp/visual-server-needed post-read-clear.sh (PNG Read)
                                                             visual-gate.sh (server found)
turn ends with gate armed          /tmp/skipped-gate         prompt-gate.sh (1 turn later)
stop-gate blocks (n times)         /tmp/stop-gate-blocks     stop-gate.sh (gate clear)
                                                             post-read-clear.sh (PNG Read)
visual file edited (broad)         .claude/verify/.dirty     verify-gate.sh (note passes)
```

Single-PNG Read clears ALL flags. Reading any one preview PNG is the universal gate exit.

---

## Hook Execution Order Per Tool Call

```
MODEL CALLS: Write("/path/to/Component.tsx", content)
                │
                ├─ 1. PreToolUse → eyes-precheck.sh      [EXIT 2 = BLOCK]
                │       • Gate 1: pending screenshots?
                │       • Gate 2: server was down?
                │
                ├─ 2. PreToolUse → scope-check.sh        [advisory — injects context]
                │       • "Is this file in scope?"
                │
                ├─ 3. PreToolUse → research-gate.sh      [EXIT 2 = BLOCK]
                │       • New project, no commits, no scores.md?
                │
                │  (if all pass)
                ▼
            WRITE EXECUTES
                │
                ├─ 4. PostToolUse → post-edit-mark-dirty.sh  [async]
                │       • Touch .claude/verify/.dirty
                │
                └─ 5. PostToolUse → visual-gate.sh            [120s timeout]
                        • Detect visual file
                        • Screenshot localhost + Vercel
                        • Video if animation/3D
                        • Arm /tmp/visual-gate-pending
                        • Inject paths into additionalContext
```

```
MODEL CALLS: Bash("git commit -m 'fix layout'")
                │
                ├─ 1. PreToolUse → deploy-gate.sh        [advisory]
                ├─ 2. PreToolUse → code-gate.sh          [tsc check]
                ├─ 3. PreToolUse → visual-block.sh       [visual state check]
                └─ 4. PreToolUse → eyes-precheck.sh      [EXIT 2 = BLOCK if gate armed]
                        • Allowlisted? (node screenshot.js, npm run dev, ffmpeg...)
                          NO: is gate armed + is this a finishing command?
                            YES → EXIT 2: "Read these PNGs first"
```

```
MODEL ENDS TURN (text output, no trailing tool call)
                │
                ├─ 1. Stop → memory-writeback.sh
                ├─ 2. Stop → stop-gate.sh               [{"decision":"block"} = BLOCK TURN]
                │       • /tmp/visual-gate-pending fresh?
                │         → refuse to let turn end
                │         → inject PNG paths back into loop
                │         → budget: 3 blocks, then fallback
                └─ 3. Stop → verify-gate.sh             [exit 2 = BLOCK TURN]
                        • .claude/verify/.dirty exists + note missing/failing?
                          → block
```

---

## The Three Bypass Routes (and How Each Is Closed)

### Route 1: "Done" via text, no trailing tool call

```
Classic bypass: Write code → say "Looks great, done!" → turn ends
                                                         ↑
                                              stop-gate.sh fires here
                                              {"decision":"block"}
                                              Model back in loop, sees PNG paths
```

### Route 2: Run the gate-check ritual and ignore it

```
Classic bypass: eyes-precheck.sh trains model to run:
                  ls /tmp/visual-gate-pending
                Model runs it, sees flag, says "noted" → moves on

Close: eyes-precheck.sh intercepts that exact Bash command.
       Running ls /tmp/visual-gate-pending WHILE gate is armed
       → EXIT 2 BLOCK: "Reading a PNG is the only exit. You cannot
         run the check and ignore it."
```

### Route 3: Deploy via MCP when CLI fails

```
Classic bypass: autonomous-operations.md routes to
                mcp__claude_ai_Vercel__deploy_to_vercel when CLI fails
                → no PreToolUse Bash matcher fires

Close: hooks.json has explicit PreToolUse matchers for:
         mcp__claude_ai_Vercel__deploy_to_vercel
         mcp__plugin_vercel_vercel__*
       Both run eyes-precheck.sh. Gate applies to MCP deploys too.
```

---

## Visual File → Hook Response Map

| File changed | Server state | Gate fires | Output |
|---|---|---|---|
| `Component.tsx` | Running :3000 | visual-gate.sh | localhost screenshots → pending |
| `Component.tsx` | Running :3000 + `.vercelurl` | visual-gate.sh | localhost + Vercel screenshots → pending |
| `Component.tsx` | Not running | visual-gate.sh | server-needed + Vercel screenshots (if .vercelurl) |
| `HeroAnimation.tsx` (motion keyword) | Running | visual-gate.sh | screenshots + desktop video + mobile video + frames |
| `shader.glsl` | Running | visual-gate.sh | screenshots + video (3D extension always) |
| `api/route.ts` | Any | visual-gate.sh | exit 0 (not a visual file) |
| `README.md` | Any | visual-gate.sh | exit 0 |

---

## Skill Execution Pattern Within This System

When a model executes a skill or idea, the lifecycle above applies with these additions:

```
SKILL INVOKED
     │
     ├── 1. Check: does a matching skill exist?
     │         YES → Skill() tool BEFORE any reasoning, any code
     │
     ├── 2. Research gate (new project)
     │         ls scores.md || BLOCK → research first
     │
     ├── 3. Execute skill steps
     │         Each Write/Edit → visual-gate.sh arms pending
     │         Each Read(PNG) → gate cleared
     │
     ├── 4. Skill output: screenshot-verified at every iteration
     │         Frame-by-frame: describe what pixels show
     │         Claim must come from PNG, not from code intent
     │
     ├── 5. Write .claude/verify/latest.md
     │         Spec items → PASS (not "probably PASS")
     │
     └── 6. Declare done
               Only after: gate clear + verify note written + no FAILs
```

### What "verified" looks like

```
UNVERIFIED (will be caught):
  "The component renders correctly."
  "The animation looks smooth."
  "The layout should be responsive."

VERIFIED (required):
  "scroll-0.png shows: headline 'Build Fast' in Inter 64px bold,
   centered, above a dark background. CTA button 'Get Started' in
   teal, with correct padding. No overlap. Footer visible in frame_021."
```

The difference: unverified claims come from code intent. Verified claims come from pixels.

---

## Project Setup Checklist

```bash
# Per-project
echo 3000 > .devport         # dev server port (skip for auto-scan 3000-8080)
echo 'https://x.vercel.app' > .vercelurl  # for Vercel vs local comparison

# Capture tools (global install, not per-project)
# ~/screenshot.js   — static PNG captures
# ~/record.js       — scroll video
# ffmpeg            — frame extraction from webm

# Screenshot a single URL or port
node ~/screenshot.js 3000 0,540,1080                              # local
node ~/screenshot.js https://x.vercel.app 0,540,1080 --prefix vercel  # deployed

# Scroll video (required for any animation/3D/Framer/GSAP content)
node ~/record.js 3000              # desktop 1440×900
node ~/record.js 3000 --mobile     # mobile 390×844

# Extract and review frames
ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png
# Read: frame_001 (top), frame_NNN (middle), frame_final-3, final-2, final-1
# Iron Law: footer must appear in the final frame
```

---

## Enforcement Grades (Current — v1.2)

| Gate | Grade | Mechanism | Bypass route closed |
|---|---|---|---|
| visual-gate.sh auto-screenshot | 9/10 | PostToolUse, no opt-out | Screenshots skipped |
| eyes-precheck Write/Edit block | 9/10 | PreToolUse exit 2 | Next edit before looking |
| eyes-precheck Bash finish-gate | 9/10 | PreToolUse exit 2 | git commit before looking |
| eyes-precheck MCP deploy gate | 9/10 | PreToolUse exit 2 | Vercel MCP bypass |
| stop-gate turn-end block | 9/10 | Stop `decision:block` | Done-in-text, no tool call |
| verify-gate note required | 8/10 | Stop exit 2 | Undocumented visual claims |
| message-display brand | 7/10 | MessageDisplay transform | Done keyword with gate armed |
| prompt-gate next-turn injection | 8/10 | UserPromptSubmit additionalContext | Gate bypassed last turn |
| build-eyes screenshot on build | 7/10 | PostToolUse Bash | npm build not visually verified |

**System grade: 9.5/10**

Residual 0.5: stop-gate budget is 3 blocks, not infinite. Liveness requires it. After
budget exhaustion, enforcement falls back to next-turn injection (8/10). A `PreTextOutput`
hook (not available in Claude Code) would close this.

---

## Key Files

| Path | Role |
|---|---|
| `hooks/visual-gate.sh` | Core: auto-screenshot, auto-video, arm pending flag |
| `hooks/eyes-precheck.sh` | Core: block writes/deploys/rituals while gate armed |
| `hooks/post-read-clear.sh` | Core: PNG Read → clear all gate flags |
| `hooks/stop-gate.sh` | Core: block turn from ending while gate armed |
| `hooks/verify-gate.sh` | Stage 2: block until written verification note passes |
| `hooks/post-edit-mark-dirty.sh` | Sets .dirty flag on every visual file edit |
| `hooks/prompt-gate.sh` | Session: inject rules + skipped-gate nuclear handler |
| `hooks/message-display-gate.sh` | Backstop: brand "done" text with GATE VIOLATION |
| `hooks/build-eyes.sh` | Build: screenshot Vercel on npm build success |
| `hooks.json.example` | Full hooks.json config to copy |
| `RULES.md` | Human-readable system reference |
| `rules/core-four.md` | The 4 non-negotiable rules in Iron Law format |
| `rules/eyes-always.md` | Visual verification Iron Laws with canonical failures |
| `/tmp/visual-gate-pending` | Active flag: screenshots taken, not yet Read |
| `/tmp/visual-server-needed` | Active flag: edit with no server (local unverified) |
| `/tmp/skipped-gate` | Backstop: gate was armed at turn-end |
| `/tmp/stop-gate-blocks` | Counter: stop-gate budget for current episode |
| `/tmp/preview/*.png` | Screenshots (deleted on Read) |
| `/tmp/preview/frames/frame_*.png` | Video frames (purged after 30 min) |
| `.claude/verify/.dirty` | Project flag: visual file edited since last note |
| `.claude/verify/latest.md` | Project: written verification note (spec table) |
