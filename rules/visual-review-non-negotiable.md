# Rule: Visual Review — Non-Negotiable

---

## Iron Law — Fires on Observable State, Not on Intent

**Observable trigger:**
```bash
git diff HEAD --name-only | grep -qE '\.(tsx|css|svg|png|jpg|webm)'
```
Exit 0 (match found) → STOP. Screenshot + video BEFORE any further code change, BEFORE any "done" statement.

**Thought "I'll check visuals at the end" = Iron Law violated.**
**Thought "This is just a quick fix" = Iron Law violated.**
**Thought "The animation should look fine" = Iron Law violated.**

The bash check doesn't care about your reasoning. It exits 0 or it doesn't.

---

## Required Captures Per Iteration

```bash
# 1. Screenshot — all 4 viewports (mobile, desktop, 4K, 5K)
node ~/screenshot.js <port> 0,540,1080

# 2. Scroll video — full page, must include footer in final frame
node ~/record.js <port>

# 3. Mobile video
node ~/record.js <port> --mobile

# 4. Extract frames for review
ffmpeg -i review.webm -vf fps=2 frames/frame_%03d.png
```

**Harness scroll formula:** `document.documentElement.scrollHeight - window.innerHeight`
Harness must end with explicit `scrollTo(0, scrollMax)`. Footer NOT in final frame = harness broken — fix before scoring.

**Required viewports:** 375×812 @2x (mobile), 1440×900 (desktop), 2560×1440 (4K), 2560×1440 @2x (5K sim).
Missing any = INCOMPLETE. Do not score incomplete captures.

---

## Required Review Steps

1. Read all 4 viewport PNGs with the Read tool — open each, describe section by section what is visible on screen.
2. Read video frames: min 6 frames spread across timeline, PLUS the final 3 frames to verify footer.
3. Compare against previous iteration at matching viewports. Describe what changed.
4. Compare against reference sites (Palantir / Veeva / ServiceNow for enterprise; project-specific for others).
5. Each score dimension must cite TWO observations: one from PNG (composition, contrast, type) + one from video (motion, transitions, depth). For animated dimensions, video is dominant.
6. Any visible regression at any viewport → score drops. No exceptions.

**"Looking" means:** Read tool on actual PNG file. Not: "I assume the capture succeeded." Not: "The code should produce X."

---

## Canonical Failure 1 — iter-16 (Block Reign): Code-as-proxy scoring

GLSL shader lifted from hero-only to fullpage. Code change was real. Score went +0.25 (6.25 → 6.5). Toby opened the deploy and saw regression instantly:
- Compliance section destroyed — 0.52 alpha put animated node grid behind ghost "COMPLIANT" type
- Mobile broken — sections had transparency → flat dark blob
- Hero contrast degraded — node network became background, not texture

The code was "better." The website was worse. The score went up. **Reason: screenshot was never opened.** Score came from intent.

Iter-18 repair pass rolled back to iter-15. The +0.25 was an illusion. This wasted time and money.

---

## Canonical Failure 2 — iter-19 (Block Reign): Incomplete scroll + single-viewport blindness

Element collisions near footer zone. Toby caught it manually by scrolling the live site. Not visible in captured video because harness scroll stopped short of the true bottom.

Root cause 1: `document.body.scrollHeight` instead of `document.documentElement.scrollHeight - window.innerHeight`. No explicit scroll-to-bottom.

Root cause 2: All captures at 1440×900 only. Toby's 5K iMac renders at 2560 CSS pixels wide. Layout bugs above 1440px were invisible.

---

## Overlap Gate

Any two elements visibly overlapping at any viewport (not intentional layering) = FAIL. Do not score as pass. Fix and re-capture.

---

## Scoring Requirement

Each dimension must cite two quoted observations:
- Static: `"[Screenshot description from PNG]"`
- Motion: `"[Motion description from video frame]"`

For Motion presence, Depth + lighting, animated Hero: video observation is primary. Static observation is secondary.

Score from what is visible. Not from what the code intends to show.

---

## This Rule Applies to All Projects

Any project with a visual output — website, UI, dashboard, landing page — is subject to this rule.
The iter-16 failure is the reference case for code-as-proxy scoring.
The iter-19 failure is the reference case for incomplete scroll and single-viewport blindness.
