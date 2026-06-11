#!/bin/bash
# PostToolUse — Write|Edit
# Auto-screenshot + auto-video on visual file changes.
#
# Screenshot always:  any .tsx/.css/.svg/.png/.html change
# Video also runs:    .glb/.gltf/.glsl/.vert/.frag/.wgsl (3D assets always)
#                     path/name contains animation/3D keywords
#                     file content imports framer-motion, @react-three, gsap, etc.
#
# Port resolution: .devport file (precise) → auto-scan 3000–3005 (fallback)
# Output: additionalContext JSON with PNG + video frame paths injected into reasoning.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only fire on visual/code file types
if ! echo "$FILE_PATH" | grep -qE '\.(tsx|ts|jsx|js|css|scss|svg|png|jpg|html|glb|gltf|glsl|vert|frag|wgsl|splinecode)$'; then
  exit 0
fi

# Must be a visual file (not just any .ts)
if ! echo "$FILE_PATH" | grep -qE '\.(tsx|jsx|css|scss|svg|png|jpg|html|glb|gltf|glsl|vert|frag|wgsl|splinecode)$'; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Write project-scoped marker (used by deploy-gate.sh)
PROJECT_DIR=$(python3 -c "import os; print(os.path.dirname('$FILE_PATH'))" 2>/dev/null || dirname "$FILE_PATH")
MARKER="/tmp/visual-gate-$(echo "$PROJECT_DIR" | md5 2>/dev/null || echo "$PROJECT_DIR" | md5sum | cut -c1-8)"
echo "$FILE_PATH" >> "$MARKER"

# ── Determine if video is needed ──────────────────────────────────────────────
VIDEO_NEEDED=false

# 1. Always video for 3D asset files
if echo "$FILE_PATH" | grep -qiE '\.(glb|gltf|glsl|vert|frag|wgsl|splinecode)$'; then
  VIDEO_NEEDED=true
fi

# 2. Path or filename contains animation / 3D keywords
if echo "$FILE_PATH" | grep -qiE '(hero|Hero|animation|Animation|motion|Motion|three|Three|r3f|R3F|canvas|Canvas|shader|Shader|particle|Particle|globe|Globe|earth|Earth|scene|Scene|gsap|GSAP|framer|Framer|carousel|Carousel|transition|scroll|parallax|orbit|Orbit|sphere|Sphere|webgl|WebGL)'; then
  VIDEO_NEEDED=true
fi

# 3. File content imports animation / 3D libraries
if [ "$VIDEO_NEEDED" = "false" ] && [ -f "$FILE_PATH" ]; then
  if grep -qE "(framer-motion|@react-three|gsap|useSpring|AnimatePresence|motion\.|<Canvas|OrbitControls|useFrame|useAnimation|stagger|whileInView|viewport|animate\(|timeline\(|ScrollTrigger|Lottie|rive)" "$FILE_PATH" 2>/dev/null; then
    VIDEO_NEEDED=true
  fi
fi

# ── Port resolution ────────────────────────────────────────────────────────────
DEV_PORT=""

# 1. Walk up from file to find .devport (most precise)
SEARCH_DIR="$PROJECT_DIR"
for _ in 1 2 3 4 5; do
  [[ -z "$SEARCH_DIR" || "$SEARCH_DIR" == "/" ]] && break
  if [ -f "$SEARCH_DIR/.devport" ]; then
    DEV_PORT=$(tr -d '[:space:]' < "$SEARCH_DIR/.devport")
    break
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

# 2. Auto-scan common ports (fallback)
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

# ── Capture ───────────────────────────────────────────────────────────────────
SHOT_EXIT=1
VERCEL_SHOT_EXIT=1
VIDEO_DESKTOP_EXIT=1
VIDEO_MOBILE_EXIT=1
FRAMES_EXTRACTED=false

if [ -n "$DEV_PORT" ]; then
  mkdir -p /tmp/preview /tmp/preview/frames

  # Screenshot localhost (always) — saves as scroll-{y}.png
  node ~/screenshot.js "$DEV_PORT" 0,540,1080 > /tmp/screenshot-gate.log 2>&1
  SHOT_EXIT=$?

  # Screenshot Vercel URL side-by-side (if .vercelurl exists) — saves as vercel-{y}.png
  if [ -n "$VERCEL_URL" ]; then
    node ~/screenshot.js "$VERCEL_URL" 0,540,1080 --prefix vercel > /tmp/screenshot-vercel-gate.log 2>&1
    VERCEL_SHOT_EXIT=$?
  fi

  # Video — desktop + mobile (when animation/3D detected)
  if [ "$VIDEO_NEEDED" = "true" ]; then
    node ~/record.js "$DEV_PORT" > /tmp/record-desktop-gate.log 2>&1
    VIDEO_DESKTOP_EXIT=$?

    node ~/record.js "$DEV_PORT" --mobile > /tmp/record-mobile-gate.log 2>&1
    VIDEO_MOBILE_EXIT=$?

    # Extract frames from desktop video
    if [ $VIDEO_DESKTOP_EXIT -eq 0 ] && [ -f "/tmp/preview/review.webm" ]; then
      rm -f /tmp/preview/frames/frame_*.png
      ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png > /dev/null 2>&1
      FRAMES_COUNT=$(ls /tmp/preview/frames/frame_*.png 2>/dev/null | wc -l | tr -d ' ')
      [ "$FRAMES_COUNT" -gt 0 ] && FRAMES_EXTRACTED=true
    fi
  fi

  python3 - "$BASENAME" "$DEV_PORT" "$SHOT_EXIT" "$VIDEO_NEEDED" "$VIDEO_DESKTOP_EXIT" "$VIDEO_MOBILE_EXIT" "$FRAMES_EXTRACTED" "$VERCEL_URL" "$VERCEL_SHOT_EXIT" << 'PYEOF'
import sys, json, glob, os

basename         = sys.argv[1]
port             = sys.argv[2]
shot_exit        = int(sys.argv[3])
video_needed     = sys.argv[4] == "true"
video_desk_exit  = int(sys.argv[5])
video_mob_exit   = int(sys.argv[6])
frames_extracted = sys.argv[7] == "true"
vercel_url       = sys.argv[8]
vercel_shot_exit = int(sys.argv[9])

parts = []

# Localhost screenshots
if shot_exit == 0:
    pngs = sorted(glob.glob('/tmp/preview/scroll-*.png'))
    if pngs:
        paths_str = '\n'.join(f'  {p}' for p in pngs[:4])
        parts.append(
            f"LOCALHOST SCREENSHOTS (port {port}) — Read each PNG:\n{paths_str}"
        )
else:
    parts.append(f"screenshot.js FAILED — run manually: node ~/screenshot.js {port} 0,540,1080")

# Vercel screenshots (side-by-side comparison)
if vercel_url:
    if vercel_shot_exit == 0:
        vpngs = sorted(glob.glob('/tmp/preview/vercel-*.png'))
        if vpngs:
            vpaths_str = '\n'.join(f'  {p}' for p in vpngs[:4])
            parts.append(
                f"VERCEL SCREENSHOTS ({vercel_url}) — Compare against localhost:\n{vpaths_str}\n"
                f"  Look for: font rendering, image sizes, missing assets, layout reflow."
            )
    else:
        parts.append(
            f"Vercel screenshot FAILED for {vercel_url}\n"
            f"  Run manually: node ~/screenshot.js '{vercel_url}' 0,540,1080 --prefix vercel"
        )
elif shot_exit == 0:
    parts.append(
        f"TIP: Add .vercelurl to project root for automatic deployed-vs-local comparison.\n"
        f"  echo 'https://your-project.vercel.app' > .vercelurl"
    )

# Video
if video_needed:
    video_parts = []

    if video_desk_exit == 0:
        video_parts.append("  Desktop: /tmp/preview/review.webm + review.mp4")
    else:
        video_parts.append("  Desktop video FAILED — run: node ~/record.js " + port)

    if video_mob_exit == 0:
        video_parts.append("  Mobile:  /tmp/preview/review-mobile.webm (if saved)")
    else:
        video_parts.append("  Mobile video FAILED — run: node ~/record.js " + port + " --mobile")

    if frames_extracted:
        frames = sorted(glob.glob('/tmp/preview/frames/frame_*.png'))
        total  = len(frames)
        # Show first, middle, and last 3
        key_frames = []
        if total > 0: key_frames.append(frames[0])
        if total > 4: key_frames.append(frames[total // 2])
        key_frames += frames[-3:]
        key_frames = list(dict.fromkeys(key_frames))  # dedup, preserve order
        frame_str = '\n'.join(f'  {f}' for f in key_frames)
        video_parts.append(
            f"\n  FRAMES EXTRACTED ({total} total) — Read these key frames:\n{frame_str}"
            f"\n  Iron Law: footer MUST be visible in the final frame."
        )
    else:
        video_parts.append("  Frames not extracted — run: ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png")

    parts.append(
        "ANIMATION/3D DETECTED — VIDEO CAPTURED:\n" + '\n'.join(video_parts)
    )

context = (
    f"VISUAL GATE — {basename}\n\n"
    + '\n\n'.join(parts)
    + "\n\nDescribe section by section what is visible. "
    + ("Read final 3 frames — footer must be visible. " if video_needed else "")
    + "'Looks good' without opening files = Iron Law violated."
)
print(json.dumps({"additionalContext": context}))
PYEOF

else
  # No dev server — inject strong reminder
  python3 - "$BASENAME" "$VIDEO_NEEDED" << 'PYEOF'
import sys, json
basename     = sys.argv[1]
video_needed = sys.argv[2] == "true"
context = (
    f"VISUAL GATE — {basename} changed (visual" + ("/3D+animation" if video_needed else "") + " file).\n"
    f"No dev server found on ports 3000–3005.\n"
    f"Start dev server, then:\n"
    f"  node ~/screenshot.js <port> 0,540,1080\n"
    + (f"  node ~/record.js <port>          # desktop scroll\n"
       f"  node ~/record.js <port> --mobile  # mobile scroll\n"
       f"  ffmpeg -i /tmp/preview/review.webm -vf fps=2 /tmp/preview/frames/frame_%03d.png\n"
       if video_needed else "")
    + "Or write the port to .devport in your project root for auto-detection."
)
print(json.dumps({"additionalContext": context}))
PYEOF
fi
