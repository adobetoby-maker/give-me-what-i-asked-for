# Rule: Autonomous Operations

---

## Iron Laws — Non-Negotiable, No Exceptions

These fire on observable events, not on thoughts. They cannot be rationalized away.

**Iron Law 0 — Win Before Asking:**
Try 3–5 times using different methods before reporting to the user. Hermes's rule is 90
attempts before asking for help. Default is action, not questions. Silence ≠ stuck.
Observable trigger: first failure → method 2 immediately. Second failure → method 3.
Third failure → method 4. Only after 3–5 genuine attempts using different tools/approaches
may an obstacle be reported, and even then only with: what was tried, why each failed,
and the minimum possible ask (one URL, one command, one credential).

**Iron Law 1 — Command Failure:**
Any bash command exits non-zero → before reporting to the user → run alternatives.
"The command failed" is not a response. It is the start of a search.

**Iron Law 2 — Deploy Wall:**
Any deploy step fails for any reason → immediately run this check sequence in order:
```bash
vercel whoami                          # Option 1: Vercel CLI cached auth
env | grep -iE "cloudflare|vercel"     # Option 2: token already in env
gh repo view --json homepageUrl        # Option 3: GitHub auto-deploy already wired
# Option 4: ToolSearch("select:mcp__claude_ai_Vercel__deploy_to_vercel")
# Option 5: create .github/workflows/deploy.yml with stored VERCEL_TOKEN
```
Run all five. Report which worked, not what failed. See ADR-0014.

**Iron Law 3 — No Stuck Reports:**
Never say "I'm stuck", "I need you to run X", or "you'll need to log in" until the
5-method rule has been exhausted in full. A user prompt is the last resort, not the
first response to friction.

**Iron Law 4 — Platform before Wrangler:**
Marketing sites, affiliate sites, portfolios → Vercel. Before writing `wrangler.jsonc`
for any new project, confirm it is a worker-bee.app subdomain with D1/R2/KV/cron needs.
If not → use Vercel. The wrangler auth wall cannot be cleared non-interactively.

---

## The 5-Method Rule (minimum — try more before asking)

Before reporting that something requires user intervention, exhaust all five.
For Hermes-style tasks (browser automation, external services, posting flows):
exhaust all methods at least 3× each before surfacing to the user.
"I tried X and it failed" is not a report — it is the reason to try Y immediately.

| # | Method | Observable check |
|---|---|---|
| 1 | **Skill** | Does a skill exist for this? Invoke it now. |
| 2 | **MCP / Plugin tool** | ToolSearch for a matching tool. Load schema and call it. |
| 3 | **WebSearch / WebFetch** | Search for how others solved it. Fetch live docs. |
| 4 | **Agent subagent** | Spawn a specialist with full context. |
| 5 | **Bash workaround** | curl, ffmpeg, jq, node — can shell achieve it? |

**Triggers — these events start the 5-method check immediately:**
- Any bash command exits non-zero
- Any tool call returns an auth / permission error
- Any install, build, or deploy step fails
- Any "not found" or "missing" error on a file, token, or service
- Any response from an external service that is not success

**Old trigger (wrong — remove from thinking):**
~~"I don't have access to that" / "I can't see that file"~~ — too late. These are defeat
thoughts, not early-warning signals. The check runs at the FIRST failure, not after
deciding it's impossible.

---

## Tool Selection Hierarchy

For any task:
```
1. Direct tool (Read, Edit, Bash, Write)     ← always first if applicable
2. Skill invocation                          ← curated patterns
3. MCP tool                                 ← live data, external systems
4. WebSearch / WebFetch                     ← docs, research
5. Agent subagent (foreground)              ← needs results before proceeding
6. Agent subagent (background)             ← independent work, fan out
```
Never jump to 5–6 when 1–3 suffice.

---

## Model Routing

| Work type | Model |
|---|---|
| File rename, git commit, npm install, curl, image resize | `haiku` |
| TypeScript, architecture, debugging, content writing | `sonnet` (default) |
| High-stakes strategy, complex multi-system decisions | `opus` |

Haiku is underused. When spawning Agent for mechanical work, set `model: "haiku"`.

---

## Parallel Execution — Default to Fan-Out

Two independent tasks → one message, two Agent calls. Never queue what can run concurrently.

---

## Skill Invocation — Before Any Response

Matching skill exists → invoke it before writing a single word of response.
The user does not say "use the skill." If the task matches, the skill fires.

---

## Proactive Completion

"Build X" or "add X" means:
- Code written and working
- Visual verification done (screenshot + video if animated)
- SEO metadata present (public page)
- Deployed (if that's the context)
- CLAUDE.md updated (if architecture changed)
- Blueprint pushed to manage.worker-bee.app (if tracked project)

"I've added the component" without the above is incomplete.

---

## Context Efficiency

- Explore agents for broad codebase searches (not 20 Read calls)
- Subagents for large output tasks (audit reports, content generation)
- mem-search before re-deriving context from scratch
- Never re-read a file already read this session unless verifying an edit

---

## Winning Definition

A task is **won** when the observable end state is achieved — not when effort was expended.

| State | Not won | Won |
|---|---|---|
| Post goes live | "I submitted it" | CL confirmation email received |
| Deploy | "I ran vercel deploy" | `curl -sI <url>` returns 200 |
| Email sent | "I called the send API" | Delivery receipt confirmed |
| Auth login | "I clicked the link" | Authenticated session cookie exists |

When the first attempt doesn't achieve the end state, try again differently.
Route around obstacles. Use Gmail MCP + Playwright together. Use Jr. Use Hermes.
Use the Chrome DevTools MCP to connect to a live browser. Use cookies from pycookiecheat.
Try the pass?key format vs login/onetime format. Try incognito context. Try a fresh session.

**Default: never stop at attempt 1. Never report a wall until attempt 3–5.**
