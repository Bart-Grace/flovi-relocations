#!/usr/bin/env bash
# Deploy the dispatcher web app. Idempotent: a redeploy at T-20 is one command.
set -euo pipefail
cd "$(dirname "$0")/../apps/dispatcher-web"

: "${VITE_SUPABASE_URL:?export it first}"
: "${VITE_SUPABASE_PUBLISHABLE_KEY:?export it first}"

# Mandatory. This directory has no .vercel/project.json — the project was created from a
# different directory — and an unlinked deploy silently creates a brand new project.
vercel link --yes --project flovi-dispatcher-bl >&2

# Project-level env vars, not `vercel deploy --env`: that sets *runtime* env, which a static
# SPA does not have, so it is a silent no-op. Vite inlines VITE_* at BUILD time, so changing
# these has no effect until the next deploy rebuilds.
# printf, not echo: a trailing newline in the URL fails silently.
printf '%s' "$VITE_SUPABASE_URL" \
  | vercel env add VITE_SUPABASE_URL production --no-sensitive --force >&2
printf '%s' "$VITE_SUPABASE_PUBLISHABLE_KEY" \
  | vercel env add VITE_SUPABASE_PUBLISHABLE_KEY production --no-sensitive --force >&2

# Fail here, on a machine you can debug, not on the build image. Output goes to stderr:
# this script's stdout contract is exactly one line, the production alias, and npm is chatty.
npm ci >&2 && npm run build >&2

# CLI 58.x writes the immutable per-deploy URL AND a trailing JSON summary to stdout, so
# `url="$(vercel deploy ...)"` captures the whole blob. Send all of it to stderr and print
# the stable production alias as this script's only stdout line.
vercel deploy --prod --yes >&2

printf '%s\n' 'https://flovi-dispatcher-bl.vercel.app'
