# CLAUDE.md — Flovi relocations

## Rule #1 — zero manually written code
Every file is AI-generated. The operator never opens an editor. A fix arrives as a prompt, never as a hand edit.

## Version pins — resolved T+0, do not drift
| Web | Mobile |
|---|---|
| vue 3.5.41 · vite 8.2.1 · vue-router 5.2.0 | Flutter 3.44.9 (Dart 3.12.2) |
| tailwindcss 4.3.3 · @tailwindcss/vite 4.3.3 | supabase_flutter 2.17.1 (sdk >=3.9.0 <4.0.0) |
| @supabase/supabase-js 2.112.2 · typescript 7.0.2 | google_fonts 8.2.1 |
| node 24 (`.nvmrc`, Vercel build image) | `google_sign_in` is NOT a dependency |

## Layout
- `apps/dispatcher-web/` — Vue 3 + Vite + TS + Tailwind v4 · `apps/driver-flutter/` — Flutter web (CanvasKit)
- `supabase/migrations/0001_init.sql` — the data contract · `scripts/` — deploy + untracked `.deploy-ids`
- `docs/DECISIONS.md` — written live, never retrospectively · `docs/PROMPT_LOG.md` — generated at T+188

## Environment — Phase 0, verified
| | |
|---|---|
| Supabase ref | `wzryktarwyjyryriqfyd` (eu-north-1) |
| Dispatcher | https://flovi-dispatcher-bl.vercel.app |
| Driver | https://flovi-driver-bl.vercel.app |
| psql | `-h aws-0-eu-north-1.pooler.supabase.com -p 5432 -U postgres.<ref>` |
| Web env | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` — Vite inlines at build time |
| Flutter env | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` — via `--dart-define` |

Session mode (5432), **not** 6543, which cannot hold an open transaction. The direct host is IPv6-only and unreachable here — do not "fix" the pooler back to it.

## Commands
```bash
cd apps/dispatcher-web && npm run dev     # :5173 — the only allow-listed local origin
./scripts/deploy-web.sh                   # prints the production alias as its LAST stdout line
./scripts/deploy-driver.sh                # builds locally; the Vercel image has no Flutter SDK
```
Vercel CLI 58.9.0 prints the deploy URL **and** a trailing JSON block on stdout. Never `url="$(vercel deploy)"`.

## Data contract
The schema is the source of truth. **Propose a migration; never invent a column.** If a field is missing, say so.
- Status is `text` + CHECK, never an enum: `open · booked · in_transit · completed · cancelled`
- The client never sends `dispatcher_id` or `status` — column defaults handle both
- Booking is **RPC-only** (`book_request`). Drivers have no UPDATE policy, by design: RLS is row-level, so any
  driver UPDATE policy would also let them rewrite `origin`, `destination` and `price_cents`
- Delete is a status change to `cancelled`. Never a SQL `DELETE`
- **Every mutation ends with `.select()`. An empty result is an error, never a success** — PostgREST answers a
  policy rejection with HTTP 200 and an empty array, so a silent RLS failure looks exactly like a success

## Security invariants
- `sb_publishable_…` ships in **both** bundles by design. RLS evaluated against `auth.uid()` is the real boundary
- `sb_secret_` / `service_role` / the Google client secret / the DB password **never leave the machine** —
  not into the repo, not into a bundle, not into a prompt. They live in the shell env and `scripts/.deploy-ids`
- Google's Authorized **redirect URI** is always and only the Supabase callback. App URLs are **origins**
- Never `drop publication supabase_realtime` — it wipes every other table's replication

## Design tokens & banned defaults
- Tokens in `src/style.css` under `@theme`; dark mode is `@custom-variant dark (&:where(.dark, .dark *));`
  — `darkMode:'class'` and `tailwind.config.js` do not exist in v4
- Status colours are fixed: open=amber · booked=blue · in_transit=indigo · completed=emerald · cancelled=zinc.
  Always a dot + label pill. Never render bare status text
- Tailwind v4 names only: `shadow-xs/sm`, `rounded-xs/sm`, `outline-hidden`, `ring-3`, `shrink-*`, `grow-*`,
  slash opacity (`bg-black/50`), and an explicit colour on every bordered element — the default is `currentColor`
- **Banned:** centered `max-w-2xl <h1>` · default indigo buttons · `bg-gray-100` cards with `shadow-md` ·
  bare `<table>` · the literal string "Loading..." · emoji as icons · `alert()` / `confirm()`

## Working agreement
- Smallest diff that satisfies the prompt. No unrelated refactors. No new dependency without asking first
- Respect the prompt's file allow-list; touching anything outside it is a defect, not initiative
- Say **"I could not verify this"** rather than claiming success. Never say "should work" — run it and paste output
- The Supabase client is a plain module `const`. Never `ref()`, `reactive()`, or inside a store
- Realtime order is fixed: `getSession()` → `realtime.setAuth(token)` → re-auth on `TOKEN_REFRESHED` → only then
  create the channel, in `onMounted`, removed in `onUnmounted`. Never a channel at module top level

## Commit convention
Conventional Commits with an app scope: `feat(web):`, `fix(driver):`, `chore(db):`, `docs:`.
One commit per accepted prompt. Trailers where they apply: `Prompt:`, `Pushback:`, `Fix:`.
**Never squash. Never force-push.** The history is a graded artifact.

## Known traps
_(empty — fill from docs/DECISIONS.md as they are hit)_
