#!/bin/bash
# UserPromptSubmit hook — fires before Claude processes every user message
# Output: JSON {"additionalContext":"..."} — injected into reasoning context, not just terminal
# Two gates: SKILL GATE (precise skill→task map) + FILES-FIRST GATE (local before external)

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', '').lower())
except:
    print('')
" 2>/dev/null)

[[ -z "$PROMPT" ]] && exit 0

SKILL_NAME=""
SKILL_REASON=""
FILES_GATE=false

# ── SKILL GATE ─────────────────────────────────────────────────────────────────
# 18 task→skill patterns. When matched, inject exact Skill() call into context.

if echo "$PROMPT" | grep -qiE "(build (a |the )?((new )?site|website|landing page|page for)|create (a |the )?((new )?site|website)|new site|make.*website|website for|mvp for|build.*(web app|app for))"; then
  SKILL_NAME="landing-page-generator"
  SKILL_REASON="new site / landing page detected — research-first (ls scores.md) required"
fi

if echo "$PROMPT" | grep -qiE "(write (a |the )?(blog|post|article)|blog post|seo post|content piece|long-form|[0-9][,0-9]*[- ]word (post|article|piece))"; then
  SKILL_NAME="seo-aeo-blog-writer"
  SKILL_REASON="blog / article writing"
fi

if echo "$PROMPT" | grep -qiE "(keyword research|keyword strategy|keyword map|seo audit|crawl|search ranking|search visibility|on-?page seo|technical seo)"; then
  SKILL_NAME="seo-keyword-strategist"
  SKILL_REASON="SEO / keyword work"
fi

if echo "$PROMPT" | grep -qiE "(landing page copy|above.the.fold|hero copy|cta copy|conversion copy|write (the )?copy|sales page|write.*headline|value proposition copy)"; then
  SKILL_NAME="seo-aeo-landing-page-writer"
  SKILL_REASON="landing page copy"
fi

if echo "$PROMPT" | grep -qiE "(content (plan|strategy|calendar|cluster|roadmap)|topic cluster|content map|marketing plan|editorial plan|pillar (page|post)|topical authority)"; then
  SKILL_NAME="content-strategy"
  SKILL_REASON="content strategy / plan"
fi

if echo "$PROMPT" | grep -qiE "(competitor|competitive analysis|compare (to |against )?|benchmark (against|vs)|market leader|how does.*compare|what (do|does) (the )?competitor)"; then
  SKILL_NAME="competitor-profiling"
  SKILL_REASON="competitor / market research"
fi

if echo "$PROMPT" | grep -qiE "(ui component|new component|design (a |the )?(button|card|hero|section|modal|sidebar|nav|header|footer)|add (a |the )?(hero|section|component|card|banner)|redesign (the )?(page|section|layout))"; then
  SKILL_NAME="ui-ux-pro-max"
  SKILL_REASON="UI design — run UUPM design_system.py first"
fi

if echo "$PROMPT" | grep -qiE "(add (auth|login|signup|registration|authentication|sign.?in)|auth (flow|system|provider)|oauth|supabase auth|nextauth|magic link|password reset)"; then
  SKILL_NAME="nextjs-supabase-auth"
  SKILL_REASON="auth implementation"
fi

if echo "$PROMPT" | grep -qiE "(supabase (schema|table|migration|rls|policy|function|edge function)|create (table|schema|migration)|alter table|add (column|index|foreign key)|database (design|schema))"; then
  SKILL_NAME="supabase-automation"
  SKILL_REASON="Supabase / database schema work"
fi

if echo "$PROMPT" | grep -qiE "(cloudflare worker|wrangler|d1 database|r2 bucket|kv (store|namespace)|worker (cron|route|binding)|cf worker)"; then
  SKILL_NAME="cloudflare-workers-expert"
  SKILL_REASON="Cloudflare Workers / wrangler work"
fi

if echo "$PROMPT" | grep -qiE "(animation|framer motion|scroll (effect|animation)|parallax|three\.?js|r3f|react.three|shader|glsl|3d (scene|model|component)|gsap|spring animation)"; then
  SKILL_NAME="animejs-animation"
  SKILL_REASON="animation / 3D — record.js required before AND after changes"
fi

if echo "$PROMPT" | grep -qiE "(add (photos?|images?|pictures?)|source (photos?|images?)|photo for|image for|hero image|real (photos?|images?)|stock (photos?|images?))"; then
  SKILL_NAME="seo-images"
  SKILL_REASON="image sourcing"
fi

if echo "$PROMPT" | grep -qiE "(review (this |the )?code|code review|audit (the |this )?code|check (this |the )?(code|implementation)|production audit)"; then
  SKILL_NAME="production-code-audit"
  SKILL_REASON="code review"
fi

if echo "$PROMPT" | grep -qiE "^(fix|debug|error|broken|failing|crash|exception|not working|it'?s broken|doesn'?t work|something'?s wrong|why (is|does|isn'?t|doesn'?t|can'?t|won'?t))"; then
  SKILL_NAME="systematic-debugging"
  SKILL_REASON="debug / fix task — BEFORE writing any code"
fi

if echo "$PROMPT" | grep -qiE "(security audit|vuln|owasp|xss|sql injection|csrf|path traversal|pentest|security review|attack surface)"; then
  SKILL_NAME="cso"
  SKILL_REASON="security audit"
fi

if echo "$PROMPT" | grep -qiE "(playwright (test|spec|e2e)|e2e test|end.to.end test|browser test|test.*flow|test.*checkout|test.*login|automation test)"; then
  SKILL_NAME="playwright-skill"
  SKILL_REASON="E2E / Playwright testing"
fi

if echo "$PROMPT" | grep -qiE "(write (the )?(copy|tagline|headline|about (us|section)|hero text)|rewrite (the )?copy|improve (the )?copy|conversion copy)"; then
  SKILL_NAME="copywriting"
  SKILL_REASON="copywriting / conversion copy"
fi

if echo "$PROMPT" | grep -qiE "^(plan|design the architecture|architect|how should (i|we) (build|implement|structure)|what'?s? the best (way|approach) to (build|implement)|think through|walk me through (building|implementing))"; then
  SKILL_NAME="writing-plans"
  SKILL_REASON="architecture / planning — plan before any code"
fi

if echo "$PROMPT" | grep -qiE "^(ship|deploy (to )?(prod|production|vercel|live)|push to (prod|main|live)|go live|launch (the )?(site|app|feature)|release)"; then
  SKILL_NAME="vercel-deployment"
  SKILL_REASON="deploy / ship — quality gate (tsc+lint+build) first"
fi

# ── FILES-FIRST gate ───────────────────────────────────────────────────────────
if echo "$PROMPT" | grep -qE "(research|look at|show me|what (do|does|is)|find|check|add|build|create|fix|update|debug|can you see|do you see|what.*site|what.*project|how does|tell me about|what happened|remember)"; then
  FILES_GATE=true
fi

# ── Output: JSON additionalContext ─────────────────────────────────────────────
# Plain echo goes to terminal only. JSON additionalContext is injected into
# Claude's reasoning context — this is the critical difference for enforcement grade.

python3 - "$SKILL_NAME" "$SKILL_REASON" "$FILES_GATE" << 'PYEOF'
import sys, json, os, glob, time

skill      = sys.argv[1]   # may be empty string
reason     = sys.argv[2]   # may be empty string
files_gate = sys.argv[3] == "true"

parts = []

_pending      = '/tmp/visual-gate-pending'
_server_down  = '/tmp/visual-server-needed'
_skipped_gate = '/tmp/skipped-gate'
_now          = int(time.time())

# ── SKIPPED-GATE CHECK — absolute highest priority ────────────────────────────
# Fires when: Stop hook OR MessageDisplay hook detected a "done" was declared
# while a gate was armed. This is the NUCLEAR injection — overrides everything else.
if os.path.exists(_skipped_gate):
    try:
        entry = open(_skipped_gate).read().strip()
        ts    = int(entry.split(':')[0])
        flags = entry.split(':')[1] if ':' in entry else ''
        if _now - ts <= 1800:   # 30 min window — longer than pending flag
            pngs = sorted(
                glob.glob('/tmp/preview/scroll-*.png') +
                glob.glob('/tmp/preview/vercel-*.png')
            )
            png_list = '\n'.join(f'  {p}' for p in pngs[:6]) or '  (already purged — take new screenshot)'
            parts.append(
                "╔══════════════════════════════════════════════════════════════╗\n"
                "║  GATE VIOLATION — PREVIOUS TURN DECLARED DONE PREMATURELY   ║\n"
                "║                                                              ║\n"
                "║  A visual gate was ARMED when the last response ended.       ║\n"
                f"║  Flags bypassed: {flags:<45} ║\n"
                "║                                                              ║\n"
                "║  BEFORE responding to the user's new message:               ║\n"
                "║  1. Read any remaining screenshots below                    ║\n"
                "║  2. Describe what you see                                   ║\n"
                "║  3. Confirm or correct the previous 'done' claim            ║\n"
                "║  4. THEN respond to the user                                ║\n"
                "║                                                              ║\n"
                f"{'║  ' + png_list.replace(chr(10), chr(10) + '║  '):<62}║\n"
                "╚══════════════════════════════════════════════════════════════╝"
            )
            os.remove(_skipped_gate)  # clear after one injection
    except Exception:
        pass

# ── Pending screenshots check ─────────────────────────────────────────────────
pending_warning = None

if os.path.exists(_pending):
    try:
        taken = int(open(_pending).read().strip())
        if _now - taken <= 600:
            pngs = sorted(
                glob.glob('/tmp/preview/scroll-*.png') +
                glob.glob('/tmp/preview/vercel-*.png')
            )
            png_list = '\n'.join(f'  {p}' for p in pngs[:6]) or '  (check /tmp/preview/)'
            pending_warning = (
                "⚠️  UNREAD SCREENSHOTS FROM PREVIOUS TURN\n"
                "Read them NOW before responding — do not skip to the user's message:\n"
                f"{png_list}\n"
                "eyes-precheck.sh will BLOCK your next Write/Edit until you Read them."
            )
    except Exception:
        pass

if pending_warning is None and os.path.exists(_server_down):
    try:
        entry = open(_server_down).read().strip()
        ts = int(entry.split(':')[0])
        if _now - ts <= 600:
            vercel_pngs = sorted(glob.glob('/tmp/preview/vercel-*.png'))
            vercel_note = ""
            if vercel_pngs:
                vercel_note = "\n  Vercel screenshots available:\n" + \
                              '\n'.join(f'    {p}' for p in vercel_pngs[:3])
            pending_warning = (
                "⚠️  SERVER WAS DOWN DURING LAST VISUAL EDIT\n"
                "No local screenshot was captured — local build is UNVERIFIED.\n"
                f"  npm run dev -H 0.0.0.0{vercel_note}"
            )
    except Exception:
        pass

if pending_warning:
    parts.append(pending_warning)

# Always inject — Core 4 Rules (identity-level, cannot be skipped)
parts.append("""CORE 4 RULES [CHARACTER — NOT INSTRUCTIONS]:
1. NO SILENT ASSUMPTIONS — scope ambiguous? Ask ONE question before any tool call.
2. NO OVER-ENGINEERING — solve only what was asked. No extras, no cleanup, no abstractions.
3. ONLY ASKED FILES — scope-check.sh fires on Write/Edit. State reason before touching unlisted files.
4. VERIFY BEFORE DONE — run tsc + live curl + screenshot. Then — and only then — declare done.
EYES RULE: .tsx/.css/.svg changed → screenshot + video before any "done" statement.""")

# Always inject — Honesty in work and research
parts.append("""HONESTY IN WORK [ALWAYS]:
Prefix every claim about running or working code with how you know:
  VERIFIED  → I ran the command / Read the file / saw the output
  INFERRED  → I believe this based on pattern — have not confirmed
  ASSUMED   → I have not checked — this is my best guess
"It works" without VERIFIED = dishonest. The honest form is "I believe it works."
"Done" without running the gate = dishonest. The honest form is "I think it's done — running gate."

BEFORE WRITING ANY OF THESE WORDS — done, complete, finished, fixed, shipped, ready, working, resolved:
  REQUIRED: Run Bash → ls /tmp/visual-gate-pending /tmp/visual-server-needed 2>/dev/null
  If either file exists → STOP → clear the gate → THEN declare done.
  No exceptions. The check takes 1 second. Skipping it is the iter-16 failure mode.
  message-display-gate.sh intercepts your output and brands it with GATE VIOLATION if you skip.
  stop-gate.sh writes /tmp/skipped-gate at end of turn — the next user message gets a nuclear injection.

Screenshots: auto-taken by visual-gate.sh. Eyes-precheck.sh BLOCKS your next write if you
haven't Read them. The bypass you're most likely to attempt: writing "done" in text
without a Write/Edit after it. message-display-gate.sh now catches this.

HONESTY IN RESEARCH [ALWAYS]:
Do not present research findings as certainties unless you have a source.
State your confidence: "The docs say X" beats "X is how it works."
If you're recalling from training data, say so: "From training data — verify with docs."
If you haven't checked something, say "I haven't checked this" — not silence.""")

if skill:
    parts.append(f"""╔══ SKILL GATE [NON-NEGOTIABLE] ════════════════════════════════╗
║  Task pattern matched: {reason}
║  REQUIRED FIRST ACTION — before ANY reasoning, explanation, or code:
║
║    Skill({{ "skill": "{skill}" }})
║
║  Invoking this skill is an Iron Law from skill-invocation-order.md.
║  Do NOT reason through the task first. Do NOT explain what you will do.
║  Invoke the skill. Then follow it.
╚═══════════════════════════════════════════════════════════════╝""")

if files_gate:
    parts.append("""FILES-FIRST GATE: Check own files BEFORE any WebSearch or WebFetch.
  1. ls /Users/drive/ — project directory exists?
  2. CLAUDE.md project table
  3. mem-search prior work
  4. ONLY THEN: external research""")

context = "\n\n".join(parts)
print(json.dumps({"additionalContext": context}))
PYEOF
