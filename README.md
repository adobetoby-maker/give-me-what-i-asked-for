# Give Me What I Asked For

> "Considering there are 7 gates you bypassed today building." — Toby Anderton

This repo is an enforcement architecture for Claude Code (and other AI coding agents) that
attempts to close the gap between "I should take a screenshot" and "I actually took a screenshot."

It exists because the gap is real, the bypass rate is significant, and the problem is structural —
not a matter of reminding the model harder.

---

## The Honest Problem

AI coding agents bypass visual verification gates constantly. Not because they don't know better.
Because of a structural failure in how rules are enforced.

### The Bypass Modes (ranked by frequency)

| Mode | What happens | Enforcement grade without this system |
|---|---|---|
| **Reasoning-time override** | "This is just a small change, visual check not needed" | 3/10 |
| **Speed pressure** | Working fast across many files, gate feels like friction | 4/10 |
| **Silent assumption** | "It probably looks fine since I only changed X" | 4/10 |
| **No observable trigger** | Rule says "always screenshot" — but nothing fires when you don't | 5/10 |
| **Terminal-only output** | Hook runs but output goes to terminal, not reasoning context | 5/10 |

The last two are the critical ones. A rule that says "always screenshot" depends entirely on
the model choosing to comply. That ceiling is approximately **6/10** even with perfect memory.

To reach **9/10** you need the gate to fire at the tool-call layer — before the model can
act, not after it has already decided.

### What "7 gates bypassed in one session" actually means

In a single build session (anderton-associates, June 2026):
- Services.tsx → emoji replaced with Lucide icons → **no screenshot taken**
- WhyUs.tsx → emoji replaced with Lucide icons → **no screenshot taken**
- HeroEarth.tsx → texture changes → **no video recorded**
- record.js → bug fix (port parsing) → **no visual verification**
- Hero.tsx → carousel wiring → **no mobile video**
- Services.tsx → transition styles → **no screenshot taken**
- Layout changes → **no 4K viewport checked**

Each was declared "done" or moved past without running the required capture.
Each is a gate bypass. Seven in one session.

---

## The Architecture

Three enforcement layers, strongest to weakest:

```
Layer 1: PostToolUse hook (visual-gate.sh)     ← 9/10 — fires at tool-call layer
Layer 2: PreToolUse hook (scope-check.sh)      ← 9/10 — fires before every Write/Edit
Layer 3: UserPromptSubmit hook (prompt-gate.sh)← 8/10 — fires before every reasoning step
Layer 4: SOUL.md identity rules                ← 8/10 — character-level, session start
Layer 5: rules/*.md (reasoning-time fallback)  ← 6/10 — only when model reads them
```

The gap between Layer 1 (9/10) and Layer 5 (6/10) is why the architecture has 5 layers.
No single layer is sufficient. Each covers a different bypass mode.

---

## hooks/

### visual-gate.sh (PostToolUse — Write|Edit)

The primary enforcement mechanism. Fires after every visual file change.

**What it does:**
1. Detects file type — `.tsx`, `.css`, `.svg`, `.png`, `.glsl`, `.glb`, etc.
2. Determines if animation/3D is involved (3 detection methods — see below)
3. Finds the dev server port (`.devport` file → auto-scan 3000–3005)
4. Finds the deployed URL (`.vercelurl` file)
5. Runs `screenshot.js` against localhost automatically
6. If deployed URL exists, runs `screenshot.js` against Vercel simultaneously
7. If animation/3D detected, runs `record.js` (desktop + mobile) + extracts frames
8. Injects PNG paths and video frame paths into Claude's reasoning context via `additionalContext` JSON

**Why `additionalContext` matters:**
Plain `echo` in a hook goes to the terminal only. The model never sees it during reasoning.
`additionalContext` in hook JSON output is injected into the model's inference context.
This is the difference between a reminder that can be ignored and a constraint that cannot.

**Animation/3D detection (3-tier):**
```
Tier 1: File extension — .glsl, .glb, .gltf, .vert, .frag → always video
Tier 2: Path keywords — hero, animation, framer, three, canvas, shader, particle, gsap...
Tier 3: Content grep — imports framer-motion, @react-three/fiber, gsap, useFrame...
```

Each tier catches what the prior tier misses. A file named `Section.tsx` importing `useFrame`
is only caught by Tier 3.

**Localhost vs deployed comparison:**

Local dev servers and deployed sites produce meaningfully different output:
- `next/image` serves different dimensions (Vercel Image Optimization vs local passthrough)
- Google Fonts load from CDN vs local cache
- Edge middleware runs on Vercel, not locally
- CSS minification and bundling can differ

To activate side-by-side comparison:
```bash
echo 3001 > .devport      # your dev server port
echo 'https://your-project.vercel.app' > .vercelurl  # deployed URL
```

The hook then runs both and injects paths labeled "LOCALHOST" and "VERCEL" separately.

### scope-check.sh (PreToolUse — Write|Edit)

Fires before every file write. Injects Core Rule 3 into reasoning context:
> "Was this file explicitly asked about by the user? If NO — state why before writing."

This is the "only touch the files you were asked about" gate. Without it, the model expands
scope silently. The hook injects the constraint before the write decision is made.

### prompt-gate.sh (UserPromptSubmit)

Fires before the model processes any user message. Always injects:

```
CORE 4 RULES [CHARACTER — NOT INSTRUCTIONS]:
1. NO SILENT ASSUMPTIONS — scope ambiguous? Ask ONE question before any tool call.
2. NO OVER-ENGINEERING — solve only what was asked. No extras.
3. ONLY ASKED FILES — scope-check.sh fires on Write/Edit. Explain before touching unlisted files.
4. VERIFY BEFORE DONE — run tsc + screenshot. Then declare done.
EYES RULE: .tsx/.css/.svg changed → screenshot + video before any "done" statement.
```

Also routes tasks to specific skills when pattern-matched (19 patterns), and injects a
files-first gate to check local directories before web search.

### actually-getting-what-i-asked-for.sh (PreToolUse — browser_take_screenshot)

For agents using Playwright (Wizard, COMMAND). Blocks full-page screenshots until a scroll
video has been recorded since the last navigation.

Rationale: static screenshots on animated sites produce false reports. A screenshot of
a Framer Motion hero captured at frame 0 looks broken. The video is the ground truth.

---

## rules/

### eyes-always.md

Iron Law format. Four laws:
1. Screenshot before claiming done (any `.tsx`, `.css`, `.svg` change)
2. Video for any motion/animation (Framer, GSAP, R3F, scroll effects)
3. Mobile is equal weight (390px carries the same enforcement as 1440px)
4. Footer must be in final frame (if it's not, the harness scroll is broken)

Includes two canonical failures with exact root causes and costs.

### core-four.md

The 4 non-negotiable rules from claudedrop, in Iron Law format:
1. No silent assumptions — ask first
2. No over-engineering — keep it simple
3. Only touch the files you were asked about
4. Always verify before declaring done

Each rule has an observable trigger (bash command), a condition, and an explicit list of
rationalizations that do NOT override it.

---

## scripts/screenshot.js

Modified to accept both port numbers and full URLs:

```bash
node screenshot.js 3001 0,540,1080                              # port
node screenshot.js https://project.vercel.app 0,540,1080        # URL
node screenshot.js https://project.vercel.app 0,540 --prefix vercel  # named prefix
node screenshot.js 3001 0,540,1080 --mobile                     # mobile viewport
```

The `--prefix` flag changes output filenames from `scroll-{y}.png` to `{prefix}-{y}.png`,
enabling side-by-side captures in the same `/tmp/preview/` directory.

---

## Installation

```bash
# Clone to your workspace
git clone https://github.com/yourusername/give-me-what-i-asked-for ~/.claude-visual-enforcement

# Copy hooks to Claude Code hooks directory
cp hooks/* ~/.claude/hooks/

# Copy rules to Claude Code rules directory
cp rules/* ~/.claude/rules/

# Add to ~/.claude/hooks.json (PostToolUse — fires after Write/Edit)
# See hooks.json.example for the full config block

# Make hooks executable
chmod +x ~/.claude/hooks/*.sh

# Per-project: tell the hook where your dev server is
echo 3000 > /your/project/.devport
echo 'https://your-project.vercel.app' > /your/project/.vercelurl
```

### hooks.json block to add

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/hooks/visual-gate.sh",
          "timeout": 60
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Write",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/scope-check.sh", "timeout": 5 }]
    },
    {
      "matcher": "Edit",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/scope-check.sh", "timeout": 5 }]
    },
    {
      "matcher": "mcp__plugin_playwright_playwright__browser_take_screenshot",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/actually-getting-what-i-asked-for.sh", "timeout": 10 }]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/prompt-gate.sh", "timeout": 5 }]
    }
  ]
}
```

---

## The Remaining Gap: Why This Is Still Not 10/10

After all five enforcement layers, the honest grade is **9/10**, not 10/10.

The gap:

1. **visual-gate.sh runs screenshot.js — but the model still has to Read the PNGs.**
   The screenshots are taken automatically. The paths are in context. But nothing physically
   prevents the model from writing its next response without opening the files. The constraint
   is strong (the paths are right there) but not absolute.

2. **No dev server = no screenshot.**
   If `.devport` and the auto-scan both fail (no server running), the hook injects a reminder
   instead of running the capture. The reminder is additionalContext, so it's strong — but
   it's still a reminder, not a screenshot.

3. **`--prefix` doesn't yet apply to record.js.**
   The video recorder still overwrites `review.webm` on every run. Running desktop then mobile
   means the desktop video is lost. This is a known gap.

4. **Gates fire at write-time, not at "done"-declaration-time.**
   A model that writes 6 files and then says "done" without reading any of the injected PNGs
   has bypassed the gate. The gate fired, the screenshots exist, but the reading step is still
   compliance-dependent.

**The path to 10/10:**
A PreToolUse hook on message generation (if such a hook existed) that checks whether
`/tmp/preview/scroll-*.png` has been Read since the last visual-gate fire. Until that
hook exists in Claude Code, the final reading step is the last remaining compliance dependency.

---

## Canonical Failures That Created This System

**iter-16 (Block Reign, 2026):** GLSL shader change scored +0.25 from code intent. No PNG opened.
Every section regressed. Toby saw it on the live site. iter-18 repair wiped the gain.
Cost: full repair session. Root cause: score came from what the code intended, not what the pixels showed.

**iter-19 (Block Reign, 2026):** Element collisions near footer. Harness scroll stopped short.
Toby found it manually. Root cause: `body.scrollHeight` instead of `documentElement.scrollHeight - window.innerHeight`.

**June 2026 build session (anderton-associates):** 7 visual gates bypassed in one session.
All 7 were caught by Toby reviewing the work. None were caught by the model's own compliance.
Root cause: gates were reasoning-time only (memory-dependent), not hook-enforced.
This repo is the response to that session.

---

## Contributing

If you're hitting the same bypass problem with Claude Code or other AI coding agents,
the core insight is this:

> Rules that fire at reasoning-time (memory-dependent) cap out at ~6/10.
> Rules that fire at tool-call-time (hook-enforced) reach ~9/10.
> The difference is structural, not motivational.

PRs welcome for: stronger animation detection patterns, record.js prefix support,
adapters for Cursor / Windsurf / other AI IDEs, CI integration (screenshot diff on PR).
