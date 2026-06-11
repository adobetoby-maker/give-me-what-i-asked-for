# Rule: Quality Gate — Definition of Done

---

## Iron Laws — These Run Before Any "Done" Declaration

**Iron Law 1 — Code Gate (always):**
Before writing "done", "complete", "finished", "it works", or "shipped" → run this NOW:
```bash
npx tsc --noEmit 2>&1 | tail -5           # zero output = pass
npm run lint 2>&1 | grep -c "error" || true  # must be 0
npm run build 2>&1 | tail -3              # must contain "compiled successfully" or equivalent
```
If any command exits non-zero → fix before declaring done. Not "I think the build passes." Run it.

**Iron Law 2 — Visual Gate (UI changes):**
Observable trigger: `git diff HEAD --name-only | grep -qE '\.(tsx|css|svg|png)'` exits 0 → STOP → screenshot + video BEFORE any "done" statement.
```bash
git diff HEAD --name-only | grep -E '\.(tsx|css|svg|png)'
# Non-empty output = Gate 2 fires. Run:
node ~/screenshot.js <port> 0,540,1080
node ~/record.js <port>
# Then Read the PNG files. Describe what is visible. Then score.
```
"The component renders correctly" without reading a PNG = Iron Law 2 violated.

**Iron Law 3 — Deploy Gate (after any deploy):**
Observable trigger: `vercel --prod` or `wrangler deploy` exits 0 → immediately run:
```bash
curl -sI <live-url> | head -1   # must be HTTP/2 200 or HTTP/1.1 200
```
A 200 response is the gate. Anything else → investigate before reporting success.

---

## Gate 1 — Code Quality

```
□ npx tsc --noEmit → zero errors
□ npm run lint → zero errors (pre-existing warnings acceptable)
□ npm run build → succeeds
□ No console.error or console.warn in new code
□ No TODO comments in new code
□ No hardcoded secrets or API keys in source
```

---

## Gate 2 — Visual Verification (any .tsx, .css, .svg change)

```
□ Desktop PNG taken AND Read with Read tool — describe what is visible
□ Mobile PNG taken AND Read (390px viewport minimum)
□ Scroll video recorded: node ~/record.js <port>
□ Video frames extracted: ffmpeg -i review.webm -vf fps=2 frames/frame_%03d.png
□ Final frame contains footer — if not, harness is broken, fix it
□ Compared against previous iteration — no regressions at any viewport
□ Image uniqueness check if routes.ts changed:
  grep -oE 'photo-[A-Za-z0-9]+|/images/routes/[^'"'"']+' src/lib/routes.ts | sort | uniq -d
  Expected: zero output
```

Forbidden shortcuts:
- "The shader creates depth" — score from pixels only
- Desktop-only check — mobile carries equal weight
- Skipping video on any animation/Framer Motion/scroll section
- Declaring pass without opening PNG files with Read tool

---

## Gate 3 — SEO (any new public page)

Run: `curl -s <url> | grep -E '<title>|description|canonical|og:|gtag|G-' | head -20`

```
□ <title>: 30–60 chars, contains primary keyword
□ meta description: 120–160 chars
□ <link rel="canonical"> present and correct
□ og:title, og:description, og:image present
□ twitter:card present
□ HTML lang attribute set
□ H1 tag: exactly one, contains primary keyword
□ All images have descriptive alt text
□ JSON-LD: Organization or LocalBusiness on home page
□ curl -I <url>/sitemap.xml → 200
□ curl -I <url>/robots.txt → 200
□ GA4: site-specific G-XXXXXXXXXX present on every page — verify with:
    curl -s <url> | grep -oE "G-[A-Z0-9]{6,}" | head -3
  Expected IDs per site:
    medicalspanish.app          → G-7F4K8MRF8S
    constructionspanish.app     → (not yet set — add VITE_GA_ID to Vercel)
    journeymanelectricianprep.com → (not yet set — add to Vercel env)
    generalcontractorprep.com   → (not yet set — add to Vercel env)
    plumberexamprep.com         → (not yet set — add to Vercel env)
    languagethreshold.com       → check existing GA4 property
    jrsautorepair.worker-bee.app → check existing GA4 property
  FAIL if: G-ID missing, wrong ID, or someone else's tag (e.g. G-RP0TZ1MP7E on wrong site)
```

---

## Gate 4 — Performance (public-facing pages)

```
□ Hero image: next/image with priority + fetchPriority="high" + sizes prop
□ No render-blocking stylesheets beyond framework CSS
□ HTML page: curl -s <url> | wc -c → < 150000 bytes (warn) / < 500000 (fail)
□ Animations respect prefers-reduced-motion
□ No unnecessary 'use client' directives (RSC by default)
```

---

## Gate 5 — Deployment Verification

```bash
curl -sI <live-url> | head -1          # must be 200
curl -sI <live-url> | grep location    # must be https (no http redirect loop)
```

```
□ Live URL returns HTTP 200
□ HTTPS active — no HTTP
□ Mobile viewport renders correctly
□ No Vercel Authentication protection blocking public access
□ No .env file committed: git log --all --oneline -- '*.env' | head -5
□ Env vars confirmed in deployment platform
```

---

## Gate 6 — Documentation (any architectural change)

Observable trigger: `git diff HEAD --name-only | grep -qE '^(app/|src/).*\.(ts|tsx)$'` AND new routes, deps, or env vars added.

```
□ Project CLAUDE.md updated: new route, dependency, env var, or pattern
□ Failure pattern added if a real bug was discovered and fixed
□ Blueprint pushed to manage.worker-bee.app API
□ Memory updated if significant new context established
```

---

## Gate 7 — Maintenance Handoff (new site launches only)

```
□ Vercel Analytics + Speed Insights enabled
□ GitHub → Vercel auto-deploy on main confirmed
□ Content update path documented
□ 30/60/90-day next steps written
□ CLAUDE.md: lifecycle: active + last_verified: <today>
```

---

## Declaring Done

State exactly:
1. Gates run (by number)
2. Each gate result (pass / warn / fail)
3. What was deferred and why
4. One-sentence next logical step (don't take it without being asked)

Do not declare done if any applicable gate fails. Fix it first.

---

## Fast Path (targeted bug fix or single-file edit)

- Gate 1 always
- Gate 2 only if a visual file changed (`git diff HEAD --name-only | grep -E '\.(tsx|css)'`)
- Gate 5 only if deployed
- All others: state deferral explicitly
