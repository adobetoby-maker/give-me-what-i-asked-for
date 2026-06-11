# Rule: Research Before Building

---

## Iron Law — Research is Not Optional

Before writing the first line of code for any new site or major redesign:

**Check this first:**
```bash
ls scores.md 2>/dev/null || echo "MISSING"
git log --oneline -1 2>/dev/null || echo "NO COMMITS"
ls src/lib/routes.ts src/app/page.tsx 2>/dev/null | wc -l
```

If `scores.md` is MISSING → research is required. Full stop. Do not write code yet.
If the project has NO COMMITS → research is required.
If the project has no routes/pages built yet → research is required.

These are state checks, not intent checks. It does not matter whether the user said
"build," "continue," "finish," or "help me with." If the state shows a new or empty
project, research runs first.

**Iron Law: no code written until scores.md exists.**

The exception is explicit, narrow, and stated: targeted bug fixes and single-file
changes on already-built projects. Anything else requires research.

---

## Why This Keeps Getting Skipped (And Why That's Wrong)

Common rationalizations that do NOT override this rule:

| Rationalization | Reality |
|---|---|
| "We're continuing from last session" | Session boundary doesn't reset the research requirement |
| "The user just wants it built" | Building without research produces generic output |
| "I already know this space" | Training data is stale. Check what exists now. |
| "There's time pressure" | 20 min of research prevents hours of rebuilding to a bar you didn't know existed |
| "It's just a template migration" | Template migrations become real sites. Real sites compete. |

---

## The Research Protocol (20–30 min, runs once per new project)

### Phase 1 — Identify space and find references (5 min)
```bash
# Search for best-in-class examples
# WebSearch: "best [category] websites 2026"
# WebSearch: "[competitor name] site"
```
Find 3 reference sites. Screenshot each with `node ~/screenshot.js` or firecrawl.

### Phase 2 — Gap table (10 min)

| Dimension | Ref A | Ref B | Ref C | Our Target |
|---|---|---|---|---|
| Hero impact | ? | ? | ? | >best |
| Type hierarchy | ? | ? | ? | >best |
| [category-specific] | | | | |

Target must beat the best reference on every important dimension.

### Phase 3 — Write scores.md (5 min)

Save to the project root:
```
scores.md       — reference scores + gap table + "build better than X" statement
iter-00/        — reference screenshots
```

### Phase 4 — State the mandate

> "We are building this to score higher than [Reference] on [dimensions].
>  Here's the gap and how we'll close it."

This statement goes in `scores.md` and in the project CLAUDE.md under
`## Competitive Context`. Every design decision is evaluated against it.

---

## Scoring Dimensions by Project Type

**Marketing / affiliate sites (climb-*, jrs, tobyandertonmd):**
- Above-the-fold clarity (0–10)
- Hero image quality (0–10)
- CTA prominence (0–10)
- Mobile experience (0–10)
- Trust signals (0–10)
- Page load feel (0–10)

**Visual / brand sites (Block Reign, Salvorias):**
- Hero impact (0–10)
- Type hierarchy (0–10)
- Motion/animation (0–10)
- Depth and lighting (0–10)
- Editorial density (0–10)

**SaaS / product:**
- Value prop clarity (0–10)
- Social proof density (0–10)
- Pricing clarity (0–10)
- Onboarding CTA (0–10)

---

## Research Tools

| Task | Tool |
|---|---|
| Find competitor sites | WebSearch |
| Scrape a competitor page | `firecrawl:firecrawl-scrape` |
| Screenshot a live site | `node ~/screenshot.js <port>` |
| Score current site | `seo-audit` skill + visual scoring |
| Deep competitive research | `competitor-profiling` skill |
| Marketing plan / content strategy | `content-strategy` skill (invoke FIRST) |
| Photo sourcing for new site | `seo-images` skill → source Pexels/Unsplash free license |

---

## When Research Returns Zero Results

Observable check: WebSearch or Explore agent returns "no web presence found" for the business.

**This is valid research output — not a failure.** Protocol:
1. Document zero-results in scores.md: `## Online Presence: NONE — new business, no existing web footprint`
2. Switch reference sites to nearest geographic competitor (same city or 50-mile radius)
3. Score those competitors as the baseline
4. Write mandate: "Beat [closest competitor] on [top 3 dimensions]"
5. Continue to scores.md → code

This does NOT override: "maybe I should search harder first." Zero results after 3 searches = document and move on.
