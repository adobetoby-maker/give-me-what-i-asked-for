# Rule: Eyes — Visual Verification Always

Observable trigger (non-negotiable):
```bash
git diff HEAD --name-only | grep -qE '\.(tsx|css|scss|svg|png|jpg|html)'
```
Exit 0 → visual gate fires. No exceptions. No "it's just a small change."

---

## Iron Laws

**Iron Law 1 — Screenshot Before Claiming Done:**
Observable check: Did I just edit a `.tsx`, `.css`, `.svg`, `.png`, or `.html` file?
Condition: YES →
```bash
node ~/screenshot.js <port> 0,540,1080
# Then: Read each PNG with Read tool. Describe section by section what is visible.
```
"The component renders correctly" without opening a PNG = Iron Law 1 violated.

**Iron Law 2 — Video for Any Motion/Animation:**
Observable check: Does the change involve animation, transitions, scroll effects, hover states, or any Framer/GSAP/R3F component?
Condition: YES →
```bash
node ~/record.js <port>            # desktop scroll
node ~/record.js <port> --mobile   # mobile scroll
ffmpeg -i review.webm -vf fps=2 frames/frame_%03d.png
# Read at minimum: frame_001, frame_010, final 3 frames
```
Screenshots freeze mid-animation. Video is the only valid source of truth for motion.

**Iron Law 3 — Mobile is Equal Weight:**
Observable check: Did I take only a desktop screenshot?
Condition: YES → mobile is also required. A layout that looks perfect at 1440px can be broken at 390px.
```bash
node ~/record.js <port> --mobile
```
"I only checked desktop" = Iron Law 3 violated.

**Iron Law 4 — Footer Must Be in Final Frame:**
Observable check: Is the final video frame showing the footer?
Condition: NO → harness scroll is broken. Fix: `scrollTo(0, document.documentElement.scrollHeight - window.innerHeight)`
A video that stops before the footer has not covered the full page.

---

## Trigger Phrases That Fire /eyes Automatically

When any of these appear in the user's message, invoke `Skill({ skill: "eyes" })` BEFORE any other response:
- `/eyes`
- "put eyes on"
- "need eyes on"
- "eyes on"
- "something looks wrong"
- "bad layout"
- "overlap"
- "visual check"
- "check how it looks"
- "screenshot"
- "how does it look"
- "can you see it"

---

## Required Viewports

| Viewport | Command | Required |
|---|---|---|
| Desktop 1440×900 | `node ~/screenshot.js <port> 0,540,1080` | Always |
| Mobile 390×844 | `node ~/record.js <port> --mobile` | Any animation or layout change |
| 4K 2560×1440 | `node ~/screenshot.js` with 4K arg | Major layout changes |

---

## Scoring: From Pixels Only

Each score dimension requires two observations:
- Static: `"[what I see in the PNG — describe section, contrast, type]"`
- Motion: `"[what I see in the video frame — describe animation, transition, depth]"`

**Forbidden scoring inputs:**
- "The shader creates depth" — describe the pixels, not the code
- "The animation should be smooth" — read the video frames, don't assume
- Desktop score applied to mobile — different viewport, different score

---

## The Canonical Failures

**iter-16 (Block Reign):** GLSL shader change scored +0.25 from code intent. No PNG opened.
Every section regressed. Toby saw it instantly on the live site. iter-18 repair wiped the gain.
**Cost:** full repair session. **Root cause:** score came from intent, not pixels.

**iter-19 (Block Reign):** Harness scroll stopped short. Element collision near footer missed.
Toby found it manually. **Root cause:** `body.scrollHeight` instead of `documentElement.scrollHeight - window.innerHeight`.

Full protocol: `~/.claude/rules/visual-review-non-negotiable.md`

---

## Grade: 9/10
Forcing function: visual-gate.sh hook fires PostToolUse on Write|Edit for visual files — arms the gate automatically.
Gap: hook arms but doesn't force the screenshot.js run. That step still requires my compliance.
