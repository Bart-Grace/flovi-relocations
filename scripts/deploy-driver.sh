#!/usr/bin/env bash
# Deploy the driver Flutter web app. Built locally and uploaded — never git-connected,
# because the Vercel build image has no Flutter SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# scripts/.deploy-ids is untracked and holds VERCEL_ORG_ID / VERCEL_PROJECT_ID. Without it,
# `flutter build web` wipes build/web including .vercel/project.json, and the next deploy
# silently creates a NEW project on a NEW URL — after the old one is already in the
# submission email. This is the one failure in the plan marked fatal.
# shellcheck source=/dev/null
source "$ROOT/scripts/.deploy-ids"
export VERCEL_ORG_ID VERCEL_PROJECT_ID
# Exporting an unset name succeeds silently even under `set -u`, so assert explicitly:
: "${VERCEL_ORG_ID:?scripts/.deploy-ids did not set VERCEL_ORG_ID}"
: "${VERCEL_PROJECT_ID:?scripts/.deploy-ids did not set VERCEL_PROJECT_ID}"

: "${SUPABASE_URL:?export it first}"
: "${SUPABASE_PUBLISHABLE_KEY:?export it first}"

cd "$ROOT/apps/driver-flutter"

# Default CanvasKit renderer. Never --web-renderer (removed in Flutter 3.29), never --wasm.
# Output to stderr: this script's stdout contract is exactly one line, the production alias.
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" >&2

# See the note in deploy-web.sh: stdout carries a JSON block, not just the URL.
vercel deploy --prod --yes --cwd "$ROOT/apps/driver-flutter/build/web" >&2

printf '%s\n' 'https://flovi-driver-bl.vercel.app'
