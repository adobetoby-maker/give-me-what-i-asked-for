#!/bin/bash
# PostToolUse — Write|Edit
# Auto-screenshot + auto-video on visual file changes.
#
# Screenshot localhost:  any .tsx/.css/.svg/.png/.html change (if server running)
# Screenshot Vercel:     always — even when local server is down (.vercelurl required)
# Video also runs:       .glb/.gltf/.glsl/.vert/.frag/.wgsl (3D assets always)
#                        path/name contains animation/3D keywords
#                        file content imports framer-motion, @react-three, gsap, etc.
#
# Port resolution: .devport file (precise) → auto-scan 3000–3005 (fallback)
# Server gap:      no local server → sets /tmp/visual-server-needed → eyes-precheck BLOCKS
# Space keeping:   purges /tmp/preview/ files older than 30 min before each run
# Output:          additionalContext JSON with all PNG + frame paths injected into reasoning

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only fire on visual file types
if ! echo "$FILE_PATH" | grep -qE '\.(tsx|jsx|css|scss|svg|png|jpg|html|glb|gltf|glsl|vert|frag|wgsl|splinecode)$'; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
PROJECT_DIR=$(python3 -c "import os; print(os.path.dirname('$FILE_PATH'))" 2>/dev/null || dirname "$FILE_PATH")

# ── Space keeping — purge old preview files before new run ─────────────────────
mkdir -p /tmp/preview /tmp/preview/frames
find /tmp/preview -maxdepth 1 -name "*.png"  -mmin +30 -delete 2>/dev/null
find /tmp/preview -maxdepth 1 -name "*.webm" -mmin +30 -delete 2>/dev/null
find /tmp/preview -maxdepth 1 -name "*.mp4"  -mmin +30 -delete 2>/dev/null
find /tmp/preview/frames -name "frame_*.png" -mmin +30 -delete 2>/dev/null

# ── Determine if video is needed ──────────────────────────────────────────────
VIDEO_NEEDED=false

if echo "$FILE_PATH" | grep -qiE '\.(glb|gltf|glsl|vert|frag|wgsl|splinecode)$'; then
  VIDEO_NEEDED=true
fi

if echo "$FILE_PATH" | grep -qiE '(hero|Hero|animation|Animation|motion|Motion|three|Three|r3f|R3F|canvas|Canvas|shader|Shader|particle|Particle|globe|Globe|earth|Earth|scene|Scene|gsap|GSAP|framer|Framer|carousel|Carousel|transition|scroll|parallax|orbit|Orbit|sphere|Sphere|webgl|WebGL)'; then
  VIDEO_NEEDED=true
fi

if [ "$VIDEO_NEEDED" = "false" ] && [ -f "$FILE_PATH" ]; then
  if grep -qE "(framer-motion|@react-three|gsap|useSpring|AnimatePresence|motion\.|<Canvas|OrbitControls|useFrame|useAnimation|stagger|whileInView|viewport|animate\(|timeline\(|ScrollTrigger|Lottie|rive)" "$FILE_PATH" 2>/dev/null; then
    VIDEO_NEEDED=true
  fi
fi

# ── Port resolution ────────────────────────────────────────────────────────────
DEV_PORT=""

SEARCH_DIR="$PROJECT_DIR"
for _ in 1 2 3 4 5; do
  [[ -z "$SEARCH_DIR" || "$SEARCH_DIR" == "/" ]] && break
  if [ -f "$SEARCH_DIR/.devport" ]; then
    DEV_PORT=$(tr -d '[:space:]' < "$SEARCH_DIR/.devport")
    break
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

if [ -z "$DEV_PORT" ]; then
  for port in 3000 3001 3002 3003 3004 3005 4000 5173 8080; do
    if lsof -ti :"$port" > /dev/null 2>&1; then
      if curl -s --max-time 1 "http://localhost:$port" > /dev/null 2>&1; then
        DEV_PORT=$port
        break
      fi
    fi
  done
fi

# ── Vercel URL resolution ──────────────────────────────────────────────────────
VERCEL_URL=""

VSEARCH_DIR="$PROJECT_DIR"
for _ in 1 2 3 4 5; do
  [[ -z "$VSEARCH_DIR" || "$VSEARCH_DIR" == "/" ]] && break
  if [ -f "$VSEARCH_DIR/.vercelurl" ]; then
    VERCEL_URL=$(tr -d '[:space:]' < "$VSEARCH_DIR/.vercelurl")
    break
  fi
  VSEARCH_DIR=$(dirname "$VSEARCH_DIR")
done

# ── Capture — localhost ────────────────────────────────────────────────────────
SHOT_EXIT=1
VIDEO_DESKTOP_EXIT=1
VIDEO_MOBILE_EXIT=1
FRAMES_EXTRACTED=false
SERVER_RUNNING=false

if [ -n "$DEV_PORT" ]; then
  SERVER_RUNNING=true

  # Server is up — clear any stale server-needed flag
  rm -f /tmp/visual-server-needed

  # Screenshot localhost
  node ~/screenshot.js "$DEV_PORT" 0,540,1080 > /tmp/screenshot-gate.log 2>&1
  SHOT_EXIT=$?

  # Write pending flag if screenshot succeeded
  [ $SHOT_EXIT -eq 0 ] && date +%s > /tmp/visual-gate-pending

  # Video — desktop + mobile
  if [ "$VIDEO_NEEDED" = "true" ]; then
    node ~/record.js "$DEV_PORT" > /tmp/record-desktop-gate.log 2>&1
    VIDEO_DESKTOP_EXIT=$?

    node ~/record.js "$DEV_PORT" --mobile > /tmp/record-mobile-gate.log 2>&1
    VIDEO_MOBILE_EXIT=$?

    if [ $VIDEO_DESKTOP_EXIT -eq 0 ] && [ -f "/tmp/preview/review.webm" ]; then
      rm -f /tmp/preview/frames/frame_*.png
      ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png > /dev/null 2>&1
      FRAMES_COUNT=$(ls /tmp/preview/frames/frame_*.png 2>/dev/null | wc -l | tr -d ' ')
      [ "$FRAMES_COUNT" -gt 0 ] && FRAMES_EXTRACTED=true
    fi
  fi

else
  # No local server — arm the server-needed flag
  # eyes-precheck.sh will BLOCK next Write/Edit until server is started
  echo "$(date +%s):$FILE_PATH:$PROJECT_DIR" > /tmp/visual-server-needed
fi

# ── Capture — Vercel URL (always — even when local server is down) ─────────────
VERCEL_SHOT_EXIT=1

if [ -n "$VERCEL_URL" ]; then
  node ~/screenshot.js "$VERCEL_URL" 0,540,1080 --prefix vercel > /tmp/screenshot-vercel-gate.log 2>&1
  VERCEL_SHOT_EXIT=$?

  # Arm pending flag if we got Vercel screenshots even without local server
  if [ $VERCEL_SHOT_EXIT -eq 0 ] && [ $SHOT_EXIT -ne 0 ]; then
    date +%s > /tmp/visual-gate-pending
  fi
fi

# ── Inject context ─────────────────────────────────────────────────────────────
python3 - "$BASENAME" "$DEV_PORT" "$SHOT_EXIT" "$VIDEO_NEEDED" "$VIDEO_DESKTOP_EXIT" "$VIDEO_MOBILE_EXIT" "$FRAMES_EXTRACTED" "$VERCEL_URL" "$VERCEL_SHOT_EXIT" "$SERVER_RUNNING" << 'PYEOF'
import sys, json, glob

basename         = sys.argv[1]
port             = sys.argv[2]
shot_exit        = int(sys.argv[3])
video_needed     = sys.argv[4] == "true"
video_desk_exit  = int(sys.argv[5])
video_mob_exit   = int(sys.argv[6])
frames_extracted = sys.argv[7] == "true"
vercel_url       = sys.argv[8]
vercel_shot_exit = int(sys.argv[9])
server_running   = sys.argv[10] == "true"

parts = []

# Server down warning (highest priority)
if not server_running:
    vercel_note = ""
    if vercel_url and vercel_shot_exit == 0:
        vercel_note = f"\n  Vercel screenshots taken as fallback — local diff unavailable."
    parts.append(
        f"⛔ SERVER NOT RUNNING — localhost not found on ports 3000–8080\n"
        f"  Visual verification is INCOMPLETE. You cannot declare 'done' yet.\n\n"
        f"  Start the dev server:\n"
        f"    cd <project> && npm run dev -H 0.0.0.0\n"
        f"  Then the gate auto-screenshots on your next file edit.\n\n"
        f"  Or write the port: echo 3000 > .devport{vercel_note}\n\n"
        f"  eyes-precheck.sh has BLOCKED your next Write/Edit until the server is running."
    )

# Localhost screenshots
if shot_exit == 0:
    pngs = sorted(glob.glob('/tmp/preview/scroll-*.png'))
    if pngs:
        paths_str = '\n'.join(f'  {p}' for p in pngs[:4])
        parts.append(f"LOCALHOST SCREENSHOTS (:{port}) — Read each PNG:\n{paths_str}")
elif server_running:
    parts.append(f"screenshot.js FAILED — run manually: node ~/screenshot.js {port} 0,540,1080")

# Vercel screenshots
if vercel_url:
    if vercel_shot_exit == 0:
        vpngs = sorted(glob.glob('/tmp/preview/vercel-*.png'))
        if vpngs:
            vpaths_str = '\n'.join(f'  {p}' for p in vpngs[:4])
            label = "VERCEL vs LOCAL COMPARISON" if server_running else "VERCEL SCREENSHOTS (local server down)"
            parts.append(
                f"{label} ({vercel_url}):\n{vpaths_str}\n"
                f"  Compare: font rendering, image load, layout reflow, missing assets."
            )
    else:
        parts.append(
            f"Vercel screenshot FAILED ({vercel_url})\n"
            f"  Run: node ~/screenshot.js '{vercel_url}' 0,540,1080 --prefix vercel"
        )
elif server_running and shot_exit == 0:
    parts.append(
        f"TIP: echo 'https://your-project.vercel.app' > .vercelurl\n"
        f"  → auto Vercel vs local comparison on every edit."
    )

# Video
if video_needed and server_running:
    video_parts = []

    if video_desk_exit == 0:
        video_parts.append("  Desktop: /tmp/preview/review.webm")
    else:
        video_parts.append(f"  Desktop FAILED — run: node ~/record.js {port}")

    if video_mob_exit == 0:
        video_parts.append("  Mobile:  /tmp/preview/review-mobile.webm")
    else:
        video_parts.append(f"  Mobile FAILED — run: node ~/record.js {port} --mobile")

    if frames_extracted:
        frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))
        total  = len(frames)
        key_frames = []
        if total > 0: key_frames.append(frames[0])
        if total > 4: key_frames.append(frames[total // 2])
        key_frames += frames[-3:]
        key_frames = list(dict.fromkeys(key_frames))
        frame_str = '\n'.join(f'  {f}' for f in key_frames)
        video_parts.append(
            f"\n  FRAMES ({total} total) — Read these:\n{frame_str}"
            f"\n  Iron Law: footer MUST appear in the final frame."
        )
    else:
        video_parts.append(
            "  Frames not extracted — run:\n"
            "  ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png"
        )

    parts.append("ANIMATION/3D DETECTED:\n" + '\n'.join(video_parts))

context = (
    f"VISUAL GATE — {basename}\n\n"
    + '\n\n'.join(parts)
    + "\n\nDescribe section by section what is visible. "
    + ("Read final 3 frames — footer must be visible. " if video_needed else "")
    + "'Looks good' without opening files = Iron Law violated.\n"
    + "Each PNG auto-deleted when Read (space keeping)."
)
print(json.dumps({"additionalContext": context}))
PYEOF
