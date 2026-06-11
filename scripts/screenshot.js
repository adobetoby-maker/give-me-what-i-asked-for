#!/usr/bin/env node
/**
 * Visual preview — screenshots a local dev server.
 *
 * Usage:
 *   node ~/screenshot.js                              # auto-detect port, default scrolls
 *   node ~/screenshot.js 3007                         # explicit port
 *   node ~/screenshot.js 3007 0,540,810,1350          # explicit port + scroll positions
 *   node ~/screenshot.js auto 0,900                   # auto-detect + custom scrolls
 *   node ~/screenshot.js 3007 0,540 --mobile          # 390×844 iPhone viewport
 *   node ~/screenshot.js 3007 --save hero             # ~/screenshots/<project>/YYYYMMDD-HHMMSS-hero-0.png
 *   node ~/screenshot.js 3007 --save salvorias/hero   # explicit project override
 */

const { chromium }  = require('/tmp/node_modules/playwright')
const path          = require('path')
const os            = require('os')
const fs            = require('fs')
const { spawnSync } = require('child_process')

function detectProjectFromPort(port) {
  // Method 1: Next.js dev logs (project path is in the log file path)
  try {
    const result = spawnSync('find', [
      '/Users/drive', '-maxdepth', '3', '-path', '*/.next/dev/logs/next-development.log',
    ], { encoding: 'utf8', timeout: 3000 })
    for (const log of (result.stdout || '').trim().split('\n').filter(Boolean)) {
      try {
        const content = fs.readFileSync(log, 'utf8')
        const match = content.match(/http:\/\/localhost:(\d+)/)
        if (match && Number(match[1]) === port) {
          const parts = log.split('/')
          const idx = parts.indexOf('drive')
          if (idx >= 0 && parts[idx + 1]) return parts[idx + 1]
        }
      } catch {}
    }
  } catch {}
  // Method 2: lsof → process cwd (works for Vite / TanStack Start / CF Workers)
  try {
    const lsof = spawnSync('lsof', ['-ti', `:${port}`], { encoding: 'utf8' })
    const pid  = (lsof.stdout || '').trim().split('\n')[0]
    if (pid) {
      const info    = spawnSync('lsof', ['-a', '-p', pid, '-d', 'cwd', '-Fn'], { encoding: 'utf8' })
      const cwdLine = (info.stdout || '').split('\n').find(l => l.startsWith('n'))
      if (cwdLine) {
        const parts = cwdLine.slice(1).trim().split('/')
        const idx   = parts.indexOf('drive')
        if (idx >= 0 && parts[idx + 1]) return parts[idx + 1]
      }
    }
  } catch {}
  return null
}

function detectPort(explicitPort) {
  if (explicitPort && explicitPort !== 'auto') return Number(explicitPort)
  try {
    const result = spawnSync('find', [
      '/Users/drive', '-path', '*/.next/dev/logs/next-development.log',
    ], { encoding: 'utf8', timeout: 3000 })
    for (const log of (result.stdout || '').trim().split('\n').filter(Boolean)) {
      try {
        const content = fs.readFileSync(log, 'utf8')
        const match   = content.match(/http:\/\/localhost:(\d+)/)
        if (match) return Number(match[1])
      } catch {}
    }
  } catch {}
  return 3000
}

function timestamp() {
  const d   = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}${pad(d.getMonth()+1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
}

// --- arg parsing ---
const args       = process.argv.slice(2)
const isMobile   = args.includes('--mobile')
const saveIdx    = args.indexOf('--save')
const prefixIdx  = args.indexOf('--prefix')
const saveName   = saveIdx  >= 0 ? args[saveIdx  + 1] : null
const outPrefix  = prefixIdx >= 0 ? args[prefixIdx + 1] : 'scroll'
const cleanArgs  = args.filter((a, i) =>
  a !== '--mobile' &&
  a !== '--save'   && (saveIdx   < 0 || i !== saveIdx   + 1) &&
  a !== '--prefix' && (prefixIdx < 0 || i !== prefixIdx + 1)
)
const rawPort    = cleanArgs[0]
const rawScrolls = cleanArgs[1]
// Accept full URL (https://…) or port number
const isUrl      = rawPort && (rawPort.startsWith('http://') || rawPort.startsWith('https://'))
const PORT       = isUrl ? null : detectPort(rawPort)
const URL        = isUrl ? rawPort : `http://localhost:${PORT}`
const SCROLLS    = rawScrolls ? rawScrolls.split(',').map(Number) : [0, 540, 810, 1350]
const VIEWPORT   = isMobile ? { width: 390, height: 844 } : { width: 1440, height: 900 }

// --- tmp output (always written for Read tool access) ---
const TMP_OUT = '/tmp/preview'
fs.mkdirSync(TMP_OUT, { recursive: true })

// --- resolve ~/screenshots save path ---
let saveDir = null, savePrefix = null
if (saveName) {
  const ts = timestamp()
  let project, label
  if (saveName.includes('/')) {
    [project, label] = saveName.split('/', 2)
  } else {
    project = detectProjectFromPort(PORT) || '_misc'
    label   = saveName
  }
  saveDir    = path.join(os.homedir(), 'screenshots', project)
  savePrefix = `${ts}-${label}`
  fs.mkdirSync(saveDir, { recursive: true })
  console.log(`  💾 ~/screenshots/${project}/${savePrefix}-*.png`)
}

;(async () => {
  console.log(`→ ${URL}  [${VIEWPORT.width}×${VIEWPORT.height}]`)
  const browser = await chromium.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
  })
  const page = await browser.newPage()
  await page.setViewportSize(VIEWPORT)
  await page.goto(URL, { waitUntil: 'networkidle' })
  await page.waitForTimeout(1500)

  const files = []
  for (const y of SCROLLS) {
    await page.evaluate((scrollY) => {
      window.scrollTo(0, scrollY)
      const inner = document.getElementById('intel-content')
        || document.querySelector('.msgs')
        || document.querySelector('[style*="overflow-y:auto"]')
      if (inner) inner.scrollTop = scrollY
    }, y)
    await page.waitForTimeout(400)
    const tmpFile = path.join(TMP_OUT, `${outPrefix}-${y}.png`)
    await page.screenshot({ path: tmpFile })
    files.push(tmpFile)
    console.log(`  ✓ scroll ${y}px → ${tmpFile}`)
    if (saveDir) {
      const dest = path.join(saveDir, `${savePrefix}-${y}.png`)
      fs.copyFileSync(tmpFile, dest)
      console.log(`          💾 ${dest}`)
    }
  }

  await browser.close()
  console.log(`\nDone. ${files.length} screenshots in ${TMP_OUT}/`)
  if (saveDir) console.log(`      saved  → ${saveDir}/`)
})()
