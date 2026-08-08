#!/usr/bin/env bash
# Starts all four app dev servers from one place.
#   canvas             -> http://localhost:5000
#   website-frontend   -> http://localhost:4000
#   main                -> http://localhost:3000
#   learning-platform   -> http://localhost:3001

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

PIDS=()

cleanup() {
  echo
  echo "Stopping all dev servers..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

start_app() {
  local name="$1"
  local dir="$2"
  local cmd="$3"

  if [ ! -d "$dir" ]; then
    echo "Skipping $name: directory not found ($dir)"
    return
  fi

  echo "Starting $name ($dir) -> logs/$name.log"
  (cd "$dir" && eval "$cmd") >"$LOG_DIR/$name.log" 2>&1 &
  PIDS+=("$!")
}

start_app "canvas"             "$ROOT_DIR/canvas"             "npm run dev"
start_app "website-frontend"   "$ROOT_DIR/website-frontend"   "npm run dev"
start_app "main"                "$ROOT_DIR/main"                "npm run dev"
start_app "learning-platform"   "$ROOT_DIR/learning-platform"   "npm run dev"

echo
echo "All services starting. Tailing logs (Ctrl+C to stop everything)..."
echo "  canvas             http://localhost:5000"
echo "  website-frontend    http://localhost:4000"
echo "  main                http://localhost:3000"
echo "  learning-platform   http://localhost:3001"
echo

tail -n +1 -f "$LOG_DIR"/*.log &
TAIL_PID=$!
PIDS+=("$TAIL_PID")

wait
