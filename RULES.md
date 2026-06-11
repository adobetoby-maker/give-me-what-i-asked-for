# Give Me What I Asked For — The Rules

A Claude Code hook architecture that enforces visual verification before any "done" declaration.
Built because Claude bypassed 7 verification gates in a single session while building a website.

---

## The 4 Core Rules

These are injected into Claude's reasoning context on every single user message via `prompt-gate.sh`.

| # | Rule | What it prevents |
|---|---|---|
| 1 | **No silent assumptions** — scope ambiguous? Ask one question before any tool call | Work completed on the wrong file, full rework |
| 2 | **No over-engineering** — solve only what was asked, no extras, no cleanup | Scope creep, abstractions nobody asked for |
| 3 | **Only touch asked files** — state reason before touching any unlisted file | Silent changes that cause invisible regressions |
| 4 | **Verify before done** — run the gate first, every time | "Done" declared while build is broken or layout regressed |

**Eyes Rule** (corollary to Rule 4): `.tsx/.css/.svg` changed → screenshot + video before any "done" statement.

---

## The Visual Verification System

### How It Works — The Full Chain

```
1. Claude edits a .tsx / .css / .svg / .html file
       ↓
2. visual-gate.sh (PostToolUse Write|Edit)
   → auto-runs screenshot.js against localhost (if server running)
   → auto-runs screenshot.js against .vercelurl (always — even if server is down)
   → auto-runs record.js + ffmpeg frame extraction (if animation/3D detected)
   → writes /tmp/visual-gate-pending with Unix timestamp
   → purges /tmp/preview/ files older than 30 min
       ↓
3. Claude tries to write more code
       ↓
4. eyes-precheck.sh (PreToolUse Write|Edit|Bash)
   → EXIT 2 BLOCK — "Read these PNGs first"
   → lists exact file paths
       ↓
5. Claude reads a PNG from /tmp/preview/
       ↓
6. post-read-clear.sh (PostToolUse Read)
   → deletes the PNG immediately (space keeping)
   → clears /tmp/visual-gate-pending
   → purges old /tmp/preview/ files
       ↓
7. Gate cleared — Claude may continue
```

### The "Done in Text" Problem — How It's Closed

The gap: if Claude says "Done!" in plain text with no trailing Write/Edit, `eyes-precheck.sh` never fires (it only fires on tool calls).

Three layers close this:

```
Layer 1 — Stop hook (stop-gate.sh)
  Fires at the exact moment a turn tries to end.
  Returns {"decision":"block"} — the turn CANNOT end.
  Claude is forced back into the loop with exact PNG paths.
  Budget: 3 blocks per episode (prevents infinite loops on wedged captures).
  After budget: falls back to next-turn nuclear injection.

Layer 2 — MessageDisplay hook (message-display-gate.sh)
  Fires as every assistant message renders.
  If "done/complete/finished/shipped" keyword + gate is armed:
  → Appends GATE VIOLATION warning to the rendered message.
  → Warning is recorded in conversation history.
  → Claude sees it was flagged on the next turn.

Layer 3 — Ritual check blocked (eyes-precheck.sh on Bash)
  The HONESTY injection tells Claude: "run ls /tmp/visual-gate-pending before declaring done."
  eyes-precheck.sh intercepts that exact Bash command and BLOCKS it.
  Claude cannot check the file and move on. Reading a PNG is the only exit.
```

---

## Hook Map

### UserPromptSubmit — fires before Claude processes every user message

| Hook | What it does |
|---|---|
| `prompt-gate.sh` | Injects Core 4 Rules + HONESTY blocks into reasoning context. Checks `/tmp/skipped-gate` (nuclear injection if last turn declared done prematurely). Checks pending/server-down flags. Routes task types to skills. |

### SessionStart

| Hook | What it does |
|---|---|
| `session-start.sh` | Memory sync, project context, model routing guide, skills menu, agent status. |

### Stop + SubagentStop — fires at end of every turn

| Hook | What it does |
|---|---|
| `stop-gate.sh` | **BLOCKING.** If visual gate is armed at turn-end, returns `{"decision":"block"}`. Claude cannot finish the turn without clearing the gate. Budget-capped at 3 blocks. Writes `/tmp/skipped-gate` as backstop. |

### MessageDisplay — fires as every assistant message renders

| Hook | What it does |
|---|---|
| `message-display-gate.sh` | Scans message for done/complete/shipped keywords. If gate is armed, appends GATE VIOLATION warning to rendered message. Warning persists in conversation history. |

### PreToolUse — fires before every tool call, can EXIT 2 to BLOCK

| Matcher | Hook | What it does |
|---|---|---|
| `Write` + `Edit` | `eyes-precheck.sh` | **BLOCK** if `/tmp/visual-gate-pending` is fresh. Lists exact PNGs to Read. |
| `Write` + `Edit` | `eyes-precheck.sh` | **BLOCK** if `/tmp/visual-server-needed` is fresh (no dev server when file was edited). |
| `Bash` | `eyes-precheck.sh` | **BLOCK** finishing commands (`git commit`, `git push`, `vercel`, `wrangler`, `deploy`) + the gate-check ritual itself (`ls /tmp/visual-gate-pending`) while gate is armed. Allowlisted: `screenshot.js`, `record.js`, `ffmpeg`, `npm run dev`, `curl localhost`. |
| `mcp__claude_ai_Vercel__deploy_to_vercel` | `eyes-precheck.sh` | **BLOCK** MCP-routed Vercel deploy while gate armed. Closes the CLI-failure fallback path that otherwise bypasses all gates. |
| `mcp__plugin_vercel_vercel__*` | `eyes-precheck.sh` | **BLOCK** plugin Vercel MCP deploys while gate armed. |
| `Write` + `Edit` | `scope-check.sh` | Injects Core Rule 3 reminder before every file write. |
| `Bash` | `deploy-gate.sh` | Platform decision gate before any deploy command. |
| `Bash` | `code-gate.sh` | TypeScript check before deploy. |
| `Bash` | `visual-block.sh` | Visual verification gate before certain Bash commands. |
| `Bash` | `command-boot.sh` | Mission-completion gate. Fires on `vercel --prod`, `curl -sI`, `active.log`, "done logged" patterns. Requires: tsc pass + live URL 200 + screenshot before Done. |
| `Write` | `research-gate.sh` | Blocks new code if no `scores.md` and no commits (new project needs research first). |
| `browser_navigate` | `wizard-boot.sh` | Injects Wizard EYES protocol before browser navigation. Record → extract frames → read key frames → footer check. |
| `browser_take_screenshot` | `actually-getting-what-i-asked-for.sh` | Playwright screenshot gate. |

### PostToolUse — fires after every tool call

| Matcher | Hook | What it does |
|---|---|---|
| `Read` | `post-read-clear.sh` | If file is a PNG from `/tmp/preview/`: delete it immediately, clear pending flag, purge old preview files. |
| `Write\|Edit` | `visual-gate.sh` | Auto-screenshot + auto-video. Detects visual files, finds dev port, screenshots localhost + Vercel, runs `record.js` for animation/3D. Writes pending flag. |
| `Bash` | `visual-clear.sh` | Clears visual state after Bash commands. |
| `Bash` | `commit-gate.sh` | Post-commit verification gate. |
| `Bash` | `build-eyes.sh` | Fires after `npm run build`, `npx tsc`, `npm run dev`. Screenshots Vercel URL on build success. Clears server-needed flag when dev server starts. Arms pending flag. |

---

## Flag Files

| File | Written by | Cleared by | Meaning |
|---|---|---|---|
| `/tmp/visual-gate-pending` | `visual-gate.sh` (on screenshot success) | `post-read-clear.sh` (PNG Read) | Screenshots taken, not yet Read |
| `/tmp/visual-server-needed` | `visual-gate.sh` (when no server found) | `visual-gate.sh` (when server found on next edit) OR `post-read-clear.sh` (PNG Read — Vercel fallback satisfies gate) | File edited with no dev server running |
| `/tmp/skipped-gate` | `stop-gate.sh`, `message-display-gate.sh` | `prompt-gate.sh` (one-shot, cleared after injection) | Turn ended with gate still armed |
| `/tmp/stop-gate-blocks` | `stop-gate.sh` (increments per block) | `stop-gate.sh` (cleared when no gate armed) | Block budget counter for current episode |
| `/tmp/preview/*.png` | `visual-gate.sh` (screenshot.js output) | `post-read-clear.sh` (immediate delete on Read) | Screenshot files |
| `/tmp/preview/frames/frame_*.png` | `visual-gate.sh` (ffmpeg extraction) | Purge after 30 min | Video frame files |

---

## Project Setup

### Required files per project

```bash
# Port for auto-screenshot (optional — auto-scanned if missing)
echo 3000 > .devport

# Deployed URL for Vercel vs local comparison (optional but recommended)
echo 'https://your-project.vercel.app' > .vercelurl
```

### Screenshot + video tools

```bash
# Static screenshots (all 3 scroll positions)
node ~/screenshot.js <port> 0,540,1080
node ~/screenshot.js https://your-project.vercel.app 0,540,1080 --prefix vercel

# Scroll video (required for animations, Framer Motion, R3F, GSAP)
node ~/record.js <port>
node ~/record.js <port> --mobile

# Extract video frames
ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png
```

---

## Animation / 3D Detection

`visual-gate.sh` automatically triggers video recording (not just screenshots) when any of these are true:

**By file extension:** `.glb` `.gltf` `.glsl` `.vert` `.frag` `.wgsl` `.splinecode`

**By path/filename keyword:** `hero` `animation` `motion` `three` `r3f` `canvas` `shader` `particle` `globe` `earth` `scene` `gsap` `framer` `carousel` `transition` `scroll` `parallax` `orbit` `sphere` `webgl`

**By file content (grep):** `framer-motion` `@react-three/fiber` `gsap` `useSpring` `AnimatePresence` `OrbitControls` `useFrame` `ScrollTrigger` `AnimatePresence` `whileInView`

---

## Enforcement Grades

| Gate | Grade | Mechanism |
|---|---|---|
| Edit → screenshot auto-taken | 9/10 | PostToolUse hook, no opt-out |
| Next Write blocked until PNG Read | 9/10 | PreToolUse exit 2, no opt-out |
| "Done in text" caught same turn | 9/10 | Stop hook `decision:block`, forced back into loop |
| "Done in text" caught on next turn | 8/10 | prompt-gate.sh nuclear injection |
| "Done" rendered → warning appended | 7/10 | MessageDisplay hook transforms message |
| npm build → screenshot Vercel | 7/10 | PostToolUse Bash, build detection |
| Server down → blocked | 8/10 | Server-needed flag + eyes-precheck |
| git commit while gate armed | 9/10 | eyes-precheck.sh Bash gate |
| MCP Vercel deploy while gate armed | 9/10 | eyes-precheck.sh MCP branch |

**System grade: 9.5/10**

Remaining 0.5: after 3 Stop-blocks, the session is allowed to end (required for liveness). Closing the final 0.5 requires a `PreTextOutput` hook that does not exist in Claude Code.

### Bugs Fixed (v1.1 — Fable assessment findings)

| Bug | Symptom | Fix |
|---|---|---|
| `stop_hook_active` early exit | Budget was effectively 1 not 3. Any forced-continuation turn exited 0 even with screenshots unread. | Removed early exit. Budget counter alone controls liveness. |
| `visual-server-needed` not cleared on Read | Reading a Vercel fallback PNG cleared `visual-gate-pending` but not `visual-server-needed`, creating a deadlock. | `post-read-clear.sh` now clears both flags on any PNG Read. |
| MCP deploy ungated | `mcp__claude_ai_Vercel__deploy_to_vercel` had no PreToolUse matcher. `autonomous-operations.md` explicitly routes to MCP when CLI fails — an escape hatch through every deploy gate. | Added PreToolUse matchers for Vercel MCP deploy tools. `eyes-precheck.sh` MCP branch handles the block. |

---

## Canonical Failures That Built This

**iter-16 (Block Reign):** GLSL shader change scored +0.25. No screenshot was opened. Score came from intent, not pixels. Every section regressed. Toby saw it on the live site immediately. Repair pass wiped the gain. Cost: full session.

**iter-19 (Block Reign):** Element collisions near footer. Missed because harness scroll stopped short (`body.scrollHeight` instead of `documentElement.scrollHeight - window.innerHeight`). Toby found it manually.

**Session that prompted this repo:** 7 verification gates bypassed in one session while building a website. All bypassed by text output — saying "done" without a trailing tool call that would trigger `eyes-precheck.sh`. The Stop hook blocking mechanism was the solution.

---

## HONESTY Protocol

Every claim about running code requires a prefix:

```
VERIFIED  → I ran the command / Read the file / saw the output
INFERRED  → I believe this based on pattern — have not confirmed
ASSUMED   → I have not checked — this is my best guess
```

"It works" without VERIFIED = dishonest.  
"Done" without running the gate = dishonest.  

Before writing `done / complete / finished / shipped / fixed / ready`:  
**Required:** `Bash → ls /tmp/visual-gate-pending /tmp/visual-server-needed`  
If either exists → clear the gate first → then declare done.  
(Note: `eyes-precheck.sh` blocks this very Bash command while a gate is armed — reading a PNG is the only exit.)

---

## Repository

https://github.com/adobetoby-maker/give-me-what-i-asked-for
