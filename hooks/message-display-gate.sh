#!/bin/bash
# MessageDisplay hook — three independent transforms run on every assistant message:
#
#  Transform 1 — ASTERISK STRIPPER (always)
#    Removes **url**, **`code`**, **/path/** formatting that breaks copied links.
#    Rule: no-asterisks-in-urls-or-paths.md
#
#  Transform 2 — STUCK-REPORTER DETECTOR (always)
#    Catches "I can't / you'll need to / I'm unable" before the user sees them.
#    Appends the API wall reminder. Rule: autonomous-operations.md Iron Law 3
#
#  Transform 3 — VISUAL GATE VIOLATION (when visual flags armed)
#    Catches "done/complete/shipped" while screenshots are unread.
#    Rule: visual-review-non-negotiable.md
#
# Returns {"action":"transform","content":...} when any transform fires.
# Returns {"action":"show"} when message passes clean.

INPUT=$(cat)
NOW=$(date +%s)

python3 - "$NOW" << 'PYEOF'
import sys, json, re, glob, time, os

now = int(sys.argv[1])

# ── Extract raw message text ──────────────────────────────────────────────────
try:
    d = json.loads(sys.stdin.read())
except Exception:
    print('{"action":"show"}')
    sys.exit(0)

def extract_text(msg):
    if isinstance(msg, list):
        return ' '.join(b.get('text','') for b in msg
                        if isinstance(b, dict) and b.get('type') == 'text')
    if isinstance(msg, dict):
        content = msg.get('content', '')
        if isinstance(content, list):
            return ' '.join(b.get('text','') for b in content
                            if isinstance(b, dict) and b.get('type') == 'text')
        return str(content)
    return str(msg) if msg else ''

original = extract_text(d.get('message', ''))
text = original

transforms_applied = []

# ══════════════════════════════════════════════════════════════════════════════
# Transform 1 — Asterisk Stripper
# Patterns: **https://...**, **`...`**, **/path/...**
# Also catches single-asterisk italic variants.
# ══════════════════════════════════════════════════════════════════════════════
def strip_bold_urls(s):
    # **https://...** or **http://...**
    s = re.sub(r'\*\*(https?://[^\s*`]+)\*\*', r'\1', s)
    # **`code`** — bold code spans
    s = re.sub(r'\*\*(`[^`]+`)\*\*', r'\1', s)
    # **/path/...** — bold paths
    s = re.sub(r'\*\*(/[^\s*]+)\*\*', r'\1', s)
    # *https://...* — italic URL
    s = re.sub(r'\*(https?://[^\s*`]+)\*', r'\1', s)
    return s

stripped = strip_bold_urls(text)
if stripped != text:
    text = stripped
    transforms_applied.append('asterisk-strip')

# ══════════════════════════════════════════════════════════════════════════════
# Transform 2 — Stuck Reporter Detector
# Catches "I can't / I'm unable / you'll need to / I don't have access"
# Rule: autonomous-operations.md Iron Law 3
# ══════════════════════════════════════════════════════════════════════════════
STUCK_PHRASES = re.compile(
    r"\b(i can'?t (do|access|reach|connect|find|get|use|see|fetch|read|write|modify|deploy|log|send|receive)|"
    r"i('?m| am) unable to|"
    r"i cannot (do|access|reach|connect|find|get|use|see|fetch|read|write|modify|deploy|log|send|receive)|"
    r"you'?ll need to (log|sign|authenticate|install|run|open|visit|go|click|provide|enter|grant|configure)|"
    r"requires you to (log|sign|authenticate|install|grant|provide)|"
    r"i don'?t have (access|permission|the ability)|"
    r"i'?m not able to (access|connect|authenticate|reach|use)|"
    r"would need you to|"
    r"you would need to (log|sign|authenticate|open|visit|provide))",
    re.IGNORECASE
)

# Exclude legitimate uses: "I can't reproduce", "I can't tell", "I can't see the file" etc.
STUCK_EXCLUSIONS = re.compile(
    r"i can'?t (reproduce|tell|say|confirm|guarantee|promise|determine|read your mind)|"
    r"you'?ll need to (update the|edit the|change the|test this|verify|review|confirm)",
    re.IGNORECASE
)

if STUCK_PHRASES.search(text) and not STUCK_EXCLUSIONS.search(text):
    wall_note = (
        "\n\n---\n"
        "## API WALL RULE — Autonomous Operations Iron Law 3\n\n"
        "The response above contains a 'stuck report' (I can't / you'll need to / I'm unable).\n"
        "This triggers before the user sees a wall that may not exist.\n\n"
        "**Before declaring blocked, exhaust these methods:**\n"
        "1. Retry the exact call (transient?)\n"
        "2. ToolSearch for a different MCP that does the same thing\n"
        "3. CLI: `vercel whoami` / `gh auth status` / `wrangler whoami`\n"
        "4. `grep -r 'TOKEN\\|API_KEY' ~/.claude/api-keys.env`\n"
        "5. `security find-generic-password -l \"<service>\" -w`\n"
        "6. Extract browser cookies with `pycookiecheat`\n"
        "7. Playwright to automate the dashboard UI\n"
        "8. REST fallback endpoint with stored key\n"
        "9. Bot/service account token\n"
        "10. `! vercel login` / `! gh auth login` (runs in session)\n\n"
        "**Minimum ask format** (only after 3+ methods fail):\n"
        "\"Tried N methods. Minimum fix: [1 URL / 1 command / 1 click]\"\n"
        "---"
    )
    text += wall_note
    transforms_applied.append('stuck-reporter')

# ══════════════════════════════════════════════════════════════════════════════
# Transform 3 — Visual Gate Violation
# Fires only when visual flags are armed AND message contains done/complete/etc.
# ══════════════════════════════════════════════════════════════════════════════
_pending     = '/tmp/visual-gate-pending'
_server_down = '/tmp/visual-server-needed'
_skipped     = '/tmp/skipped-gate'

pending_exists     = False
server_down_exists = False

if os.path.exists(_pending):
    try:
        taken = int(open(_pending).read().strip())
        if now - taken <= 600:
            pending_exists = True
    except Exception:
        pass

if os.path.exists(_server_down):
    try:
        entry = open(_server_down).read().strip()
        ts = int(entry.split(':')[0])
        if now - ts <= 600:
            server_down_exists = True
    except Exception:
        pass

if (pending_exists or server_down_exists):
    DONE_WORDS = re.compile(
        r'\b(done|complete|completed|finished|it works|it\'s working|shipped|ready|'
        r'deployed|verified|all set|looks good|working now|fixed|resolved|'
        r'implemented|added|built|created|updated)\b',
        re.IGNORECASE
    )
    if DONE_WORDS.search(text):
        open(_skipped, 'w').write(f"{now}:{pending_exists}:{server_down_exists}")
        warnings = []
        if pending_exists:
            pngs = sorted(
                glob.glob('/tmp/preview/scroll-*.png') +
                glob.glob('/tmp/preview/vercel-*.png')
            )
            frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))
            png_list = '\n'.join(f'  {p}' for p in pngs[:4]) or '  (check /tmp/preview/)'
            frame_note = f'\n  Video frames: {frames[0]} … {frames[-1]}' if len(frames) >= 2 else ''
            warnings.append(
                "⚠️  EYES GATE SKIPPED — screenshots taken but NOT Read.\n"
                f"Unverified:\n{png_list}{frame_note}\n"
                "Read the PNGs and re-verify before this response stands."
            )
        if server_down_exists:
            warnings.append(
                "⚠️  SERVER-DOWN GATE SKIPPED — no dev server was running.\n"
                "Local build is UNVERIFIED. Start server → screenshot → then redeclare done."
            )
        text += (
            "\n\n---\n## GATE VIOLATION — Visual Verification Not Complete\n\n"
            + "\n\n".join(warnings)
            + "\n\n**To clear:** Read the PNG files. Describe what you see. Then say done.\n---"
        )
        transforms_applied.append('visual-gate')

# ══════════════════════════════════════════════════════════════════════════════
# Return result
# ══════════════════════════════════════════════════════════════════════════════
if transforms_applied:
    print(json.dumps({"action": "transform", "content": text}))
else:
    print('{"action":"show"}')
PYEOF
