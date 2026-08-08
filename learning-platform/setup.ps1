# One-shot setup for the AI Learning Platform (Windows PowerShell).
#
#   .\setup.ps1                       # uses an existing .env, or writes a stub
#   .\setup.ps1 sk-proj-yourkeyhere   # also writes the OpenAI key into .env
#
# If PowerShell blocks the script, run it once as:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1

param([string]$OpenAiKey)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Say  ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Warn ($m) { Write-Host "!   $m" -ForegroundColor Yellow }
function Die  ($m) { Write-Host "x   $m" -ForegroundColor Red; exit 1 }

# ---------- 1. Prerequisites ----------

Say "Checking prerequisites"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Die "Node.js is not installed. Install Node 20 or newer from https://nodejs.org"
}

$nodeMajor = [int](node -p "process.versions.node.split('.')[0]")
if ($nodeMajor -lt 20) { Die "Node $(node -v) is too old. Next.js 16 needs Node 20 or newer." }

Write-Host "Node $(node -v), npm $(npm -v)"

# ---------- 2. Dependencies ----------

Say "Installing dependencies (this takes a few minutes on a fresh machine)"
npm install
if ($LASTEXITCODE -ne 0) { Die "npm install failed" }

# ---------- 3. Environment ----------

Say "Setting up .env"

# .env is gitignored on purpose, so a fresh clone never has one.
if (Test-Path .env) {
  Write-Host ".env already exists, leaving it alone"
} else {
  # A random secret so NextAuth does not fall back to the shared default.
  $secret = node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
  $key = if ($OpenAiKey) { $OpenAiKey } else { "" }

  @(
    "OPENAI_API_KEY=$key"
    "NEXTAUTH_URL=http://localhost:3001"
    "NEXTAUTH_SECRET=$secret"
    'DATABASE_URL="file:./dev.db"'
  ) | Out-File -FilePath .env -Encoding utf8

  Write-Host "Wrote .env with a freshly generated NEXTAUTH_SECRET"
}

$hasKey = (Get-Content .env | Where-Object { $_ -match '^OPENAI_API_KEY=.+' }).Count -gt 0

# ---------- 4. Database ----------

Say "Preparing the database"
npx prisma generate
if ($LASTEXITCODE -ne 0) { Die "prisma generate failed" }
npx prisma db push
if ($LASTEXITCODE -ne 0) { Die "prisma db push failed" }
Write-Host "SQLite database ready at prisma/dev.db"

# ---------- 5. Done ----------

Say "Setup complete"

if (-not $hasKey) {
  Warn "No OpenAI API key set yet."
  Warn "Open .env and fill in OPENAI_API_KEY=sk-... before starting."
  Warn "Without it, chat, voice, RAG, quizzes and slides will all fail."
  Write-Host ""
}

Write-Host @"
Start the app with:

    npm run dev

Then open http://localhost:3001 and sign in with any name.

Other commands:
    npm run build     production build (also regenerates Prisma and syncs the DB)
    npm start         run the production build
    npx prisma studio browse the database in a GUI

If port 3001 is busy:
    npx next dev -p 3002
"@
