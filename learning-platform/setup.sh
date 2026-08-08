#!/usr/bin/env bash
#
# One-shot setup for the AI Learning Platform.
#
#   ./setup.sh                        # uses an existing .env, or writes a stub
#   ./setup.sh sk-proj-yourkeyhere    # also writes the OpenAI key into .env
#
# Works on macOS, Linux, and Windows through Git Bash.

set -euo pipefail

cd "$(dirname "$0")"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m!   %s\033[0m\n' "$1"; }
die()  { printf '\033[1;31mx   %s\033[0m\n' "$1" >&2; exit 1; }

# ---------- 1. Prerequisites ----------

say "Checking prerequisites"

command -v node >/dev/null 2>&1 || die "Node.js is not installed. Install Node 20 or newer from https://nodejs.org"
command -v npm  >/dev/null 2>&1 || die "npm is not installed. It ships with Node.js."

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 20 ] || die "Node $(node -v) is too old. Next.js 16 needs Node 20 or newer."

echo "Node $(node -v), npm $(npm -v)"

# ---------- 2. Dependencies ----------

say "Installing dependencies (this takes a few minutes on a fresh machine)"
npm install

# ---------- 3. Environment ----------

say "Setting up .env"

# .env is gitignored on purpose, so a fresh clone never has one.
if [ -f .env ]; then
  echo ".env already exists, leaving it alone"
else
  # A random secret so NextAuth does not fall back to the shared default.
  SECRET="$(node -e 'console.log(require("crypto").randomBytes(32).toString("base64"))')"

  cat > .env <<EOF
OPENAI_API_KEY=${1:-}
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=$SECRET
DATABASE_URL="file:./dev.db"
EOF
  echo "Wrote .env with a freshly generated NEXTAUTH_SECRET"
fi

# Put the key in place if one was passed and the slot is still empty.
if [ -n "${1:-}" ] && grep -q '^OPENAI_API_KEY=$' .env; then
  node -e '
    const fs = require("fs");
    const key = process.argv[1];
    fs.writeFileSync(".env", fs.readFileSync(".env", "utf8").replace(/^OPENAI_API_KEY=$/m, "OPENAI_API_KEY=" + key));
  ' "$1"
  echo "Wrote the OpenAI API key into .env"
fi

HAS_KEY=0
grep -q '^OPENAI_API_KEY=.\+' .env && HAS_KEY=1

# ---------- 4. Database ----------

say "Preparing the database"
npx prisma generate
npx prisma db push
echo "SQLite database ready at prisma/dev.db"

# ---------- 5. Done ----------

say "Setup complete"

if [ "$HAS_KEY" -eq 0 ]; then
  warn "No OpenAI API key set yet."
  warn "Open .env and fill in OPENAI_API_KEY=sk-... before starting."
  warn "Without it, chat, voice, RAG, quizzes and slides will all fail."
  echo
fi

cat <<'EOF'
Start the app with:

    npm run dev

Then open http://localhost:3001 and sign in with any name.

Other commands:
    npm run build     production build (also regenerates Prisma and syncs the DB)
    npm start         run the production build
    npx prisma studio browse the database in a GUI

If port 3001 is busy:
    npx next dev -p 3002
EOF
