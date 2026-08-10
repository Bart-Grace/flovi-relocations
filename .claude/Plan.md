# Plan — Flovi 4h Build

**Ship:** dispatcher web (Vue 3) + driver app (Flutter web), Google login on both, live sync between them, both public on the internet, zero hand-written code.

**Stack:** Supabase (DB + Auth + Realtime) · Vue 3 + Vite + Tailwind v4 · Flutter web (CanvasKit) · Vercel · one public repo `flovi-relocations`.

**Rule:** every file is written by the AI. You paste prompts, run commands, verify. You never open an editor.

**Checkpoints:** `T+25` OAuth works, still zero code · `T+45` DB done · `T+50` web live · `T+65` driver live · `T+125` dispatcher done · `T+175` full loop live · `T+185` freeze · `T+200` docs · `T+240` sent.

---

## 0. Before the clock starts (10 min)

- Accounts: Supabase, Google Cloud, Vercel, GitHub. Verify: `vercel whoami` · `gh auth status` · `node -v` (≥ 22.12) · `flutter doctor` (no red Chrome line).
- **3 Google accounts in 3 Chrome profiles:** `Dispatcher`, `Driver A`, `Driver B`. Three, not two — the dispatcher cannot book its own gig (the RPC blocks it), so you need two real drivers for the double-booking demo.
- Resolve versions (paste the output into prompt 01):
  `npm view vue version; npm view vite version; npm view vue-router version; npm view tailwindcss version; npm view @supabase/supabase-js version; flutter --version`
- `gh repo create flovi-relocations --public --source=. --remote=origin` → open it in a logged-out window.

## 1. Claim both domains (T+0 → T+5)

Both Vercel URLs must exist **before** you touch the Google console, so the allow-lists get written once.

```bash
for p in flovi-dispatcher flovi-driver; do
  mkdir -p /tmp/claim/$p && cd /tmp/claim/$p && echo ok > index.html
  vercel link --yes --project $p && vercel deploy --prod --yes
done
```

**Done when:** `https://flovi-dispatcher.vercel.app` and `https://flovi-driver.vercel.app` both return 200 in incognito.
**Never rename a Vercel project** afterwards — the origin is about to be baked into Google and Supabase.

## 2. OAuth + infra — zero code (T+5 → T+25)

| # | Where | Do | Done when |
|---|---|---|---|
| 1 | Supabase | New project, nearest region, save the DB password | Settings → API shows `https://<ref>.supabase.co` + an `sb_publishable_…` key |
| 2 | Supabase | Auth → Providers → Google → **copy the callback shown there** | clipboard = `https://<ref>.supabase.co/auth/v1/callback` |
| 3 | Google Cloud | Auth Platform → Branding, then Audience: External, add all 3 accounts as test users, **Publish → In production** | the page reads *In production* |
| 4 | Google Cloud | Clients → Create → Web application. **Authorized redirect URIs = the Supabase callback, nothing else.** JavaScript origins = `http://localhost:5173` + both Vercel origins | exactly 1 redirect URI, exactly 3 origins |
| 5 | Supabase | Paste Client ID + Secret → Enable → Save | the Google row reads *Enabled* |
| 6 | Supabase | Auth → URL Configuration. Site URL = dispatcher URL. Redirect URLs: `http://localhost:5173/**`, `https://flovi-dispatcher.vercel.app/**`, `https://flovi-driver.vercel.app/**` | the test below |

**Checkpoint T+25 — still zero code.** In the *Dispatcher* profile open:
`https://<ref>.supabase.co/auth/v1/authorize?provider=google&redirect_to=http%3A%2F%2Flocalhost%3A5173%2F`
→ Google account chooser → browser lands on `localhost:5173/?code=…`. "Connection refused" is fine — the `code` param is the proof. Repeat in *Driver A* with the driver URL, then sign in once in all three profiles (this creates the `auth.users` rows the migration backfills).

> Glob rule: `*` does not cross `/` or `.`, `**` does. Google origin changes take a few minutes to propagate.

## 3. The build — one prompt per row

Prompts live in `.claude/promptsLog.md`. One commit per accepted prompt.

| T+ | Step | Prompt | Done when |
|---|---|---|---|
| 5–12 | Repo tree, `.gitignore`, `CLAUDE.md` with the pins | **01** | one commit, `CLAUDE.md` ≤ 80 lines |
| 25–45 | Whole DB contract in one migration | **02** | 4 verify queries pass + 2 test rows ✅**T+45** |
| 45–50 | Vue + Vite + Tailwind v4 scaffold + Supabase client | **03** | `npm run dev` shows a styled page |
| 48–50 | Deploy scripts for both apps, then run the web one | **04** | dispatcher URL 200 in incognito ✅**T+50** |
| 50–58 | Google login in the web app | **05** | sign-in on the prod URL → `/requests`, F5 keeps the session |
| 58–65 | Flutter shell + auth gate, deployed | **06** | Driver A signs in on the prod driver URL ✅**T+65** |
| 65–82 | App shell, request list, status pills | **07** | both seed rows with correct pills, real Google avatar in the topbar |
| 82–100 | Create / edit slide-over | **08** | create → amber *Open* pill; edit changes the row text |
| 100–125 | Realtime + money-shot toast | **09** | edit a row in the Supabase table editor → prod list patches in ~2s ✅**T+125** |
| 125–137 | Available-gigs stream (Flutter) | **10** | a request created in the web app appears in the driver app in ~2s |
| 137–148 | One-tap booking via the RPC | **11** | a tap books it, the row leaves the list via the stream |
| 148–155 | My gigs tab | **12** | the just-booked gig appears there; Driver B's tab stays empty |
| 155–175 | **Buffer** — the one OAuth/realtime problem that always happens | — | 3-window test passes in prod ✅**T+175** |
| 175–185 | Design pass, top 3 defects only | crit + **13** | fresh screenshot is clean, `npm run build` still passes ✅**T+185 freeze** |
| 185–200 | Docs: prompt log, README, REFLECTION | **14** | both README URLs load, every cited sha resolves ✅**T+200** |
| 200–212 | Rehearse the demo twice | — | the second run finishes under 5:00 |
| 212–220 | Final redeploy of both apps | — | both 200; the driver URL matches the README **string for string** |
| 220–240 | Record the walkthrough, logged-out repo check, send | — | email sent ✅**T+240** |

**The 4 migration verification queries must return:**
1. `profiles | 5` and `relocation_requests | 13` columns.
2. 6 policies, RLS `t` on both tables, every role `{authenticated}`, no `ALL`, no `DELETE` policy.
3. 2 functions, `prosecdef = t`, `proconfig = {"search_path=\"\""}`, `authenticated` can execute, `anon` cannot.
4. `supabase_realtime | public | relocation_requests` present.

## 4. Traps — read this before you debug anything

| Symptom | Cause → fix |
|---|---|
| `.subscribe()` says `SUBSCRIBED`, **zero events arrive** | supabase-js never hands the JWT to the socket → `supabase.realtime.setAuth(token)` after `getSession()` **and on every `TOKEN_REFRESHED`**, *before* any channel exists. Never create a channel at module top level. |
| A booked gig never leaves the other driver's list | Realtime evaluates the SELECT policy against the **NEW** row → SELECT must be `using (true)`, filter in the UI. |
| Blank white page in prod, `supabaseUrl is required` | Vite inlines `VITE_*` at build time → `vercel env add … --force`, **then redeploy**. `vercel deploy --env` is a no-op for a static SPA. |
| `Error 400: redirect_uri_mismatch` | The app URL went into Google's redirect URIs. Google's redirect URI is *only ever* the Supabase callback. |
| Login "works" but lands on the wrong URL | `redirectTo` is missing from the Supabase allow-list. |
| `both auth code and code verifier should be non-empty` | The PKCE verifier is localStorage-keyed to the origin that started the flow → finish each flow in the same browser + origin. |
| One booking fires three toasts | Duplicate channels (HMR / unmounted components) → one channel per concern, created in `onMounted`, removed in `onUnmounted`. |
| `TypeError: Cannot read private member` | The Supabase client got wrapped in Vue reactivity → plain module `const`, never `ref()`/`reactive()`. |
| Driver URL 404s and a `flovi-driver-abc123` project appeared | `flutter build web` wipes `build/web` incl. `.vercel/project.json` → export `VERCEL_ORG_ID`/`VERCEL_PROJECT_ID` from untracked `scripts/.deploy-ids`. **Fatal if missed.** |
| Save "succeeds", nothing changes, network shows 200 | Silent RLS rejection → **every mutation ends with `.select()`**; empty result = error. |
| `trying to use tailwindcss directly as a PostCSS plugin` | v3 setup against a v4 install → delete `postcss.config.js`, `tailwind.config.js`, autoprefixer. |
| `Could not find an option named "--web-renderer"` | Removed in Flutter 3.29 → delete the flag. Never `--wasm` either. |
| Stale Flutter build after redeploy | Service worker → verify every driver deploy in fresh incognito; strip the SW registration from `web/index.html`. |
| `Access blocked: has not completed the Google verification process` | Consent screen left in Testing → publish it. **Fatal mid-demo.** |

## 5. If you are behind — cut in this order

| Time | Trigger | Cut to | Say on stage |
|---|---|---|---|
| T+95 | Dispatcher CRUD fighting you | edit → status-change-only | "Create + status transitions cover the workflow; full edit was the cheapest thing to drop." |
| T+140 | Flutter Google OAuth still broken | magic-link or a seeded session | "Same session, same RLS, same RPC — only the credential handoff changed." |
| T+165 | Realtime not delivering | 5-second poll + refetch-on-focus | "Near-real-time was in scope; the socket wasn't worth the last hour." |
| T+200 | Polish over budget | drop from the bottom: transitions → dark toggle → focus trap → optimistic writes → inline validation → skeletons | "Ranked before I started cutting, then cut from the bottom." |

**Never cut:** the README, either live URL, the walkthrough recording, or the logged-out repo check.
**Meta-rule:** an honest cut, named in the reflection, beats a broken feature.

## 6. Demo (4:55)

**Layout, set before T+200 and never touched again:** left half = *Dispatcher* profile on `/requests`. Right top = *Driver A*, Available tab. Right bottom = *Driver B*, same gig visible. Notifications off.

**The money shot:** Driver A taps Book → on the dispatcher screen beside it, with no refresh, the pill flips to **Booked**, the driver's Google avatar + name fade in, one toast reads *"Marek booked Warsaw → Berlin."*

**The correctness shot:** Driver A and Driver B tap the same gig within a second. One gets the confirmation, the other gets exactly `This gig is no longer available`.

| Beat | Time | Where | The one sentence |
|---|---|---|---|
| 1 | 0:00 | dispatcher | "The board: every relocation request, with live status." |
| 2 | 0:25 | slide-over | "The client never sends `dispatcher_id` or `status` — the column defaults do." |
| 3 | 1:05 | edit mode | "One component, two modes; the save round-trips through `.select()`, so a rejected write can't look like success." |
| 4 | 1:30 | Driver A | "Already here, no reload — that's the Postgres change stream." |
| 5 | 2:00 | both | **money shot** — "One tap, and the dispatcher sees who took it." |
| 6 | 2:50 | Driver B | "`This gig is no longer available` — one guarded UPDATE; the loser re-evaluates and matches nothing." |
| 7 | 3:30 | My gigs | "His list; Driver B's stays empty — one broad SELECT policy, filtered where it belongs." |
| 8 | 4:00 | `0001_init.sql` | "Drivers have no UPDATE policy at all — booking is RPC-only." |
| 9 | 4:35 | GitHub | "Commit history, prompt log, both live URLs in the first five lines of the README." |
