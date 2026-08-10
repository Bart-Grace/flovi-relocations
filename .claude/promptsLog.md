# Prompt Log — Flovi

Every prompt used to build this, in order. Paste one, verify its acceptance line, commit, fill in the **Log** line under it. Nothing is written freehand.

**Method:** one dense spec up front (`plan.md`), then small verifiable slices. Every prompt below is the same skeleton filled in:

```
Context:   what already exists
Goal:      one user-visible outcome, checkable in < 5 min
Constraints: stack + pins from CLAUDE.md
  Files you may create or edit: <allow-list>   ← touch nothing else
Out of scope: the adjacent work you must NOT do, named
Acceptance: done when <observable fact>
Plan first.  ← only on the gated ones
```

**Why `Out of scope` matters most:** every other line describes work I want; that line is the only one constraining work I didn't ask for — and unrequested work is what produces the 20-file diff and the unreadable commit history (a graded row).

---

## 01 · Repo + CLAUDE.md — T+5

```
Context: Empty public repo flovi-relocations, plan.md at root, nothing scaffolded.
Goal: Commit #1 — .gitignore, folder tree, CLAUDE.md — so every later prompt inherits the same constraints.
Constraints:
- Tree: apps/dispatcher-web/, apps/driver-flutter/, supabase/migrations/, prompts/, scripts/, docs/, .nvmrc
- .gitignore FIRST: node_modules/ dist/ .vercel/ .env* build/ .dart_tool/ scripts/.deploy-ids
- CLAUDE.md, under 80 lines: hard rule #1 (zero manually written code — the operator never opens an editor);
  version pins (pasted below); repo layout; commands; data contract ("the schema is the source of truth —
  propose a migration, never invent a column"); security invariants (the sb_publishable_ key ships in both
  bundles by design, RLS against auth.uid() is the real boundary; sb_secret_/service_role/Google secret/DB
  password never leave the machine); design tokens + banned defaults; working agreement (smallest diff, no
  unrelated refactors, no new dependency without asking, say "I could not verify this" instead of claiming
  success); commit convention (Conventional Commits with app scope, one commit per accepted prompt,
  `Prompt:`/`Pushback:`/`Fix:` trailers, never squash, never force-push); an empty "Known traps" section.
- Version pins, verbatim from pre-flight: <paste npm view + flutter --version output>
Out of scope: no scaffolding, no npm create, no flutter create, no application code, no README yet.
Acceptance: `git log --oneline` shows exactly one commit and `wc -l CLAUDE.md` is ≤ 80.
```
*`.gitignore` landing after the first scaffold means 40,000 files in history — and history is graded.*
**Log:** _pending_

---

## 02 · The whole data contract in one migration — T+28 · **plan-gated**

```
Context: Supabase project live, zero tables. Three Google accounts already signed in through the authorize URL,
so auth.users has rows that predate any trigger. No application code exists anywhere.
Goal: supabase/migrations/0001_init.sql — schema, RLS, RPCs and realtime in one file, four blocks A-D,
each block ending in its own verification query.
Constraints:
- A: public.profiles (id -> auth.users on delete cascade, email, full_name, avatar_url, created_at) +
  handle_new_user() trigger (security definer, set search_path = '', reads raw_user_meta_data->>'full_name'
  and 'avatar_url', on conflict do nothing) + an idempotent backfill insert for the accounts that signed in
  before the trigger existed. public.relocation_requests: dispatcher_id uuid not null default auth.uid(),
  origin, destination, pickup_date date, notes, vehicle_type, price_cents (>= 0), status TEXT + CHECK in
  (open, booked, in_transit, completed, cancelled) — NOT an enum — driver_id, booked_at, created_at,
  updated_at; checks booked_requires_driver and driver_implies_booked_at; three indexes; touch_updated_at trigger.
- B: RLS on both tables. Every policy `to authenticated`, split per verb, never `for all`, every auth.uid()
  written as `(select auth.uid())`. SELECT on both tables is `using (true)` with an inline comment saying it is
  deliberate: Realtime evaluates the SELECT policy against the NEW row, and the dispatcher renders the booking
  driver's avatar. Writes stay strict. Include verbatim:
  `-- NOTE: drivers get no UPDATE policy at all. Booking is RPC-only.`
- C: book_request(p_request_id uuid) and release_request, both security definer set search_path = '', every
  identifier fully qualified. book_request is ONE guarded UPDATE: where id = p_request_id and status = 'open'
  and driver_id is null and dispatcher_id <> auth.uid(), returning into a row var, then
  `if not found then raise exception 'This gig is no longer available'`. Carry both reasons as inline SQL
  comments, worded to be read aloud: atomicity (under READ COMMITTED the loser blocks on the row lock,
  re-evaluates, matches nothing — no advisory lock, no SELECT FOR UPDATE) and column scoping (RLS is row-level
  only, so any driver UPDATE policy would also let them rewrite origin/destination/price_cents).
  Then revoke all from public, anon; grant execute to authenticated.
- D: alter publication supabase_realtime add table + replica identity full. NEVER drop and recreate the publication.
Out of scope: no enum types, no roles table, no role column, no DELETE policy, no seed script, no generated
TypeScript types, no client code of any kind.
Acceptance: all four blocks run top-to-bottom with zero edits, all four verification queries match, two test
rows exist, and two concurrent book_request calls from two psql sessions give one success and one error
reading exactly "This gig is no longer available".
Plan first.
```
*Schema + RLS + RPC are one slice because they are one contract — split them and you get a policy set that contradicts the function it was written for.*
**Log:** _pending_

---

## 03 · Vue scaffold + Tailwind v4 + Supabase client — T+45

```
Context: Migration applied and verified. apps/dispatcher-web/ is empty. Vercel project flovi-dispatcher-bl reserved.
Goal: A running Vite + Vue 3 + TS app with Tailwind v4 and a Supabase client, rendering one signed-out placeholder.
Constraints:
- Files: apps/dispatcher-web/** only. Versions exactly as pinned in CLAUDE.md, no other dependencies.
- Tailwind v4 is exactly: npm i tailwindcss @tailwindcss/vite; tailwindcss() in vite.config.ts plugins;
  `@import "tailwindcss";` at the top of src/style.css. NO tailwind.config.js, NO postcss.config.js, no
  autoprefixer, no @tailwind base/components/utilities. Tokens go in `@theme { --color-brand-500: oklch(...) }`
  in src/style.css; dark mode is `@custom-variant dark (&:where(.dark, .dark *));` — darkMode:'class' is gone.
- src/lib/supabase.ts is a plain module const with { auth: { flowType:'pkce', detectSessionInUrl:true,
  persistSession:true, autoRefreshToken:true } }. Never ref(), never reactive(), never inside a store.
- Boot guard: a missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY renders a banner naming the missing
  variable. A blank white page is a failure of this prompt.
- Commit .env.example with `# NEVER put sb_secret_/service_role here — it bypasses RLS`.
Out of scope: no auth flow, no router, no Pinia, no UI library, no icon package, nothing beyond App.vue.
Acceptance: `npm run dev` serves :5173, a Tailwind utility visibly applies, and removing one env var shows the
named banner rather than a white screen.
```
*Tailwind is here, not in the design slice, because the v3-config-against-v4 failure is silent — surface it while the app is one file.*
**Log:** _pending_

---

## 04 · Deploy scripts for both apps — T+48

```
Context: dispatcher-web builds locally. Both Vercel projects exist from a one-file index.html. No Flutter app yet.
Goal: Two idempotent scripts, so a redeploy at T-20 is one command with no thinking.
Constraints:
- Files: scripts/deploy-web.sh, scripts/deploy-driver.sh, apps/dispatcher-web/vercel.json,
  apps/driver-flutter/web/vercel.json, scripts/.deploy-ids.example
- Web: `vercel link --yes --project flovi-dispatcher-bl` (mandatory — the app dir has no .vercel/project.json and an
  unlinked deploy silently creates a new project), npm ci && npm run build, then vercel deploy --prod --yes.
- Vercel CLI 58.9.0 prints the per-deploy URL AND a trailing JSON summary on stdout. Do NOT write
  `url="$(vercel deploy --prod --yes)"` — it captures the whole blob. Send the CLI's own output to stderr and
  print the known production alias as the final stdout line.
- Env as PROJECT env vars: printf '%s' "$VALUE" | vercel env add NAME production --no-sensitive --force, then
  redeploy. printf not echo — a trailing newline in the URL fails silently. Never `vercel deploy --env`:
  that is runtime env, which a static SPA does not have.
- vercel.json = {"rewrites":[{"source":"/(.*)","destination":"/index.html"}]}, next to package.json, not in dist/.
  The driver's copy goes in apps/driver-flutter/web/ so `flutter build web` copies it into the wiped output.
- Driver: flutter build web --release with --dart-define for SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, then
  deploy with VERCEL_ORG_ID and VERCEL_PROJECT_ID sourced from the untracked scripts/.deploy-ids, using
  --cwd apps/driver-flutter/build/web. Never --web-renderer, never --wasm.
- Each script exits non-zero on failure, pushes the per-deploy hash URL to stderr, and prints the stable
  production alias as its final stdout line.
Out of scope: no CI, no GitHub Actions, no git-connecting the Flutter project, no Netlify path yet.
Acceptance: ./scripts/deploy-web.sh prints https://flovi-dispatcher-bl.vercel.app, that URL returns 200 in
incognito, and a deep link like /requests/abc does not 404.
```
*Written before the Flutter app exists because the ORG/PROJECT id export is the only thing preventing a brand-new `flovi-driver-abc123` URL appearing at T-25 — after the old one is already in the submission email.*
**Log:** _pending_

---

## 05 · Google OAuth in the web app — T+52 · **plan-gated**

```
Context: Scaffold deployed. Google client and the Supabase allow-list were configured in Phase 0, zero code written.
Goal: Sign in with Google, land on /requests, survive a hard refresh, sign out cleanly.
Constraints:
- Files: src/composables/useAuth.ts, src/router/index.ts, src/views/SignInView.vue, src/App.vue
- signInWithOAuth({ provider:'google', options:{ redirectTo: window.location.origin,
  queryParams:{ prompt:'select_account' } } })
- There is NO /auth/callback route and no callback component. detectSessionInUrl handles the return; routing is
  driven by onAuthStateChange.
- useAuth exports module-scoped refs (session, user, profile). No Pinia.
- The router guard awaits the initial getSession() before deciding, so a refresh does not flash the sign-in page.
Out of scope: no requests list, no profile editing, no roles or role checks, no email/password path.
Acceptance: signing in on the deployed URL lands on /requests, F5 keeps me signed in, sign-out returns to /,
and a matching row exists in public.profiles.
Plan first.
```
*Gated because it touches four files and one wrong `redirectTo` costs a console round-trip plus Google's propagation delay.*
**Log:** _pending_

---

## 06 · Flutter shell + auth gate — T+58 · **plan-gated**

```
Context: Web app authenticates. apps/driver-flutter/ is empty. Same single Google Web client; driver origin
already allow-listed.
Goal: A deployed Flutter web app where my second Google account signs in and reaches an empty two-tab shell.
Constraints:
- Files: apps/driver-flutter/** only. Dependencies: supabase_flutter and google_fonts. `google_sign_in` is
  explicitly NOT a dependency. Keep `import 'package:flutter/material.dart';`.
- main(): WidgetsFlutterBinding.ensureInitialized() -> Supabase.initialize(...
  FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce)) -> runApp. Config via --dart-define only, no
  committed constants file: publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY') — the exact name
  deploy-driver.sh passes.
- Auth gate: one StreamBuilder<AuthState> on onAuthStateChange, branching on currentSession == null.
  No go_router, no Riverpod.
- signInWithOAuth(OAuthProvider.google) with the kIsWeb redirect/launch-mode ternary and
  webOnlyWindowName: '_self'. Write NO callback-handling code — the SDK strips the params itself.
- web/index.html: real <title>, favicon, theme-color, a branded centred loading div removed in the
  flutter_bootstrap.js onEntrypointLoaded callback. Strip the service worker registration.
Out of scope: no gig list, no booking, no queries of any kind, no APK, no native sign-in path.
Acceptance: ./scripts/deploy-driver.sh prints the driver URL, Driver A signs in there in fresh incognito, and a
NavigationBar shows Available / My gigs, both empty.
```
*Deployed before either app has features, so the OAuth-on-a-real-origin problem surfaces at T+65 with 175 minutes left, not at T-30.*
**Log:** _pending_

---

## 07 · App shell, request list, status pills — T+70

```
Context: Web auth works. Two seed rows exist. Design tokens are already in CLAUDE.md.
Goal: The dispatcher's main screen — persistent shell plus a list of my requests with colour-coded status pills.
Constraints:
- Files: src/composables/useRequests.ts, src/components/AppShell.vue, StatusPill.vue, RequestList.vue,
  RequestRow.vue, EmptyState.vue
- Left rail + topbar showing the Google avatar and full_name read from profiles.
- Pills are a dot plus a label: open=amber, booked=blue, in_transit=indigo, completed=emerald, cancelled=zinc.
  Never render bare status text.
- Every query ends with .select(); an empty result is an error, never a success.
- Banned: centered max-w-2xl <h1>, default indigo buttons, bg-gray-100 cards with shadow-md, bare <table>,
  the literal string "Loading...", emoji as icons, alert()/confirm().
Out of scope: no create form, no edit, no realtime, no filters, no sorting UI, no pagination, no delete.
Acceptance: the deployed app lists both seed rows with the correct pill colours, an account with zero rows sees
a real empty state (icon + one line + CTA), and the topbar shows my actual Google avatar.
```
*Pills are here, not in the polish pass, because they are what the camera is pointed at during the money shot.*
**Log:** _pending_

---

## 08 · Create / edit slide-over — T+88

```
Context: The list renders from useRequests(). No mutations exist yet.
Goal: Create and edit a relocation request from a right-hand slide-over, with the list reflecting the save.
Constraints:
- Files: src/components/RequestSlideOver.vue, src/components/ui/*.vue, and useRequests.ts (add createRequest
  and updateRequest only — do not restructure what is there).
- One component serves both modes; edit prefills from the row passed in.
- Fields: origin, destination, pickup_date (a date input bound to the date column, never text), notes,
  vehicle_type, price_cents.
- Do NOT send dispatcher_id or status from the client — both column defaults already handle it.
- Mutations end with .select().single(); an empty result toasts the error and leaves the panel open.
- Delete is a status change to 'cancelled'. Never a SQL DELETE.
Out of scope: no realtime, no optimistic UI, no focus trap or Esc handling, no address autocomplete, no maps,
no file attachments, and no assigning a driver from this form.
Acceptance: on the deployed URL I create a request and it appears with an amber Open pill; I reopen it, change
the destination, save, and the row text changes; a CHECK violation surfaces as a toast, not a silent no-op.
```
*"No assigning a driver from this form" is load-bearing — it is exactly the field the model adds unprompted, and it would need the UPDATE policy the whole design refuses to grant.*
**Log:** _pending_

---

## 09 · Realtime subscription with setAuth — T+105 · **plan-gated**

```
Context: Dispatcher CRUD works in production. Driver app signs in but shows nothing. Zero realtime code exists.
Goal: The dispatcher list patches itself when a row changes from another client, with no refresh.
Constraints:
- Files: src/composables/useRealtime.ts, useRequests.ts (patch handlers only), and the view that mounts it.
- Exact order, no variation: getSession() -> supabase.realtime.setAuth(session.access_token) -> re-call setAuth
  on every TOKEN_REFRESHED -> only then create the channel, inside onMounted ->
  onUnmounted(() => supabase.removeChannel(channel)).
- Never create a channel at module top level; it runs before the session is restored from localStorage.
- One channel per concern. supabase.channel('name') called twice creates two channels; it does not return the
  existing one.
- INSERT/UPDATE handlers patch the local array in place. Do not refetch the list on every event.
- Money shot: on an UPDATE that fills driver_id, patch the row with that driver's avatar and full_name from
  profiles and fire exactly one toast — "<full_name> booked <origin> -> <destination>".
Out of scope: no presence, no broadcast, no reconnect UI, no RLS changes, no Flutter changes.
Acceptance: editing a row in the Supabase table editor updates the deployed dispatcher list within ~2s with no
refresh, and one update produces exactly one toast, not three.
Note: SUBSCRIBED means the channel joined — it is not proof of delivery. If zero events arrive, check setAuth
and the SELECT policy before touching anything else.
Plan first.
```
*The biggest time-sink on this build gets its own gate and its own prompt, so the failure has a one-file blast radius.*
**Log:** _pending_

---

## 10 · Available-gigs stream — T+128

```
Context: Flutter shell and auth gate are deployed. Backend has open rows. No data code in the Flutter app yet.
Goal: The Available tab lists open gigs and updates itself live.
Constraints:
- Files: lib/features/gigs/available_gigs_page.dart, lib/models/relocation_request.dart, lib/theme.dart
- .stream(primaryKey: ['id']) accepts exactly ONE filter on ONE column, then optionally .order()/.limit().
  Chaining a second .eq() is an analyzer error — apply any second filter client-side with .where().
- Store the stream in a field initialised in initState. Never build it inline in build() — that re-subscribes
  on every rebuild.
- Cards show origin -> destination on one row led by a route icon (not a bullet list), plus date and a status chip.
- Theming: ColorScheme.fromSeed, useMaterial3, light and dark, one google_fonts pairing.
Out of scope: no booking action, no My gigs tab, no search, no filters, no map, no pull-to-refresh, no detail page.
Acceptance: the deployed driver URL lists the open rows, and creating a request in the dispatcher app makes it
appear in the Flutter list within ~2s with no reload.
```
*Stream before booking: if supabase_flutter turns out not to propagate the JWT to the socket, I learn it on a read path with no write consequences.*
**Log:** _pending_

---

## 11 · One-tap booking via the RPC — T+145

```
Context: Available tab streams open gigs. book_request exists and its race behaviour is already proven in SQL.
Goal: One tap books a gig, with a confirmation step and a truthful failure path.
Constraints:
- Files: available_gigs_page.dart, lib/features/gigs/book_sheet.dart, lib/data/gig_repository.dart
- Booking is supabase.rpc('book_request', {'p_request_id': id}). Do NOT read the row first and check status in
  Dart — that is a TOCTOU race; two drivers tapping in the same second both pass it. The guard lives inside the
  RPC and nowhere else.
- Confirmation is a bottom sheet, not a default-styled AlertDialog.
- On PostgrestException, surface error.message VERBATIM in a SnackBar. The RPC already returns
  "This gig is no longer available" for the loser.
- Disable the button while the call is in flight. The row leaves the list via the stream, not manual removal.
Out of scope: no release/unbook UI, no My gigs tab, no push notifications, no optimistic removal, and no
client-side status check of any kind.
Acceptance: two windows signed in as two different drivers tap the same gig — one gets the confirmation, the
other gets a SnackBar reading exactly "This gig is no longer available", and the dispatcher list flips that
pill to Booked live in a third window.
```
*The flagship pushback, pre-written into the prompt: the model's default here is a read-then-write check, and the two-window test is the acceptance criterion precisely because it is what catches it.*
**Log:** _pending_

---

## 12 · My gigs tab — T+160

```
Context: Booking works end to end. The second IndexedStack destination is still a placeholder.
Goal: A My gigs tab listing this driver's booked gigs, live.
Constraints:
- Files: lib/features/gigs/my_gigs_page.dart, lib/data/gig_repository.dart
- Same single-filter rule: .eq('driver_id', uid) is the one allowed stream filter. Anything else is a
  client-side .where().
- Stream stored as a field; the tab stays inside IndexedStack so its state survives switching.
- Empty state is an illustrated widget with one line of copy and a CTA back to Available — never Text('No gigs').
Out of scope: no release/cancel action, no detail page, no history filter, no chat, no ratings, no earnings.
Acceptance: a gig I just booked appears under My gigs with no reload, and the other driver's My gigs tab
stays empty.
```
*The cheapest remaining slice that closes the driver's loop; everything else goes in the README's "deliberately not built" list.*
**Log:** _pending_

---

## 13 · Design pass — T+178 → freeze T+185

Always run the screenshot critique first (below), then this.

```
Context: The full cross-app loop works in production. The UI is functional and generic. Freeze is at T+185.
Goal: Close the top defects on the dispatcher list and slide-over. Nothing else.
Constraints:
- Files: only the components named in the ranked critique you just produced, plus src/style.css tokens.
- Work from the screenshot I pasted and your own ranked defect list. Fix in rank order, stop when I say stop.
- Tailwind v4 names only: shadow-xs / shadow-sm, rounded-xs / rounded-sm, outline-hidden, ring-3, shrink-*,
  grow-*, slash opacity (bg-black/50), and an explicit colour on every bordered element — the default border
  colour is now currentColor.
- Smallest possible diff. No component restructuring, no new dependencies, no layout rewrites.
Out of scope: no Tier 2 items unless I name them (skeletons, focus trap, dark toggle, transitions),
no Flutter changes, no copy rewrites, no re-theming.
Acceptance: a fresh screenshot of the same view no longer shows defects 1-3 and `npm run build` still succeeds.
```
*Asking for fixes before asking for a diagnosis is how a polish pass turns into a rewrite seven minutes before freeze.*
**Log:** _pending_

---

## 14 · Docs sprint — T+188

```
Context: Feature freeze is in effect. docs/DECISIONS.md holds the dictated entries. Transcript at
~/.claude/projects/<cwd-slug>/*.jsonl.
Goal: The four graded artifacts, generated from evidence that already exists.
Constraints:
- Files: scripts/extract-prompts.mjs, docs/prompt-log-raw.md, docs/PROMPT_LOG.md, README.md, REFLECTION.md
- Read ONE jsonl line and show me the field names before writing the extractor. Do not guess the schema.
- PROMPT_LOG.md: 10-14 phase-grouped entries, the first prompt of each phase quoted verbatim, the raw
  transcript linked as an appendix.
- README: both live URLs in the first five lines, architecture diagram, 60-second quickstart, the "why the
  publishable key is public" paragraph, and the "deliberately not built" list.
- REFLECTION.md: draft parts 1-4 from docs/DECISIONS.md and git log only. Leave part 5 a stub — I write it.
Out of scope: invent nothing that is not in DECISIONS.md or the git log; no feature work; no touching app code;
no rewriting commit messages.
Acceptance: both README URLs load in fresh incognito, every sha cited in REFLECTION.md resolves via `git show`,
and PROMPT_LOG.md contains at least 10 entries.
```
*Timeboxed as a build slice with real acceptance criteria, because four of the five scored rows live in these files and "if time permits" is how they end up thin.*
**Log:** _pending_

---

# Standing prompts

Pasted verbatim, never retyped, so the wording never drifts.

**Diagnosis first** — *always the first turn of any bug, no exceptions.*
> Do not edit code. Give me the 3 most likely root causes ranked by probability, and for each, the single cheapest observation that confirms or eliminates it.

**Skeptic pass** — *scheduled twice: right after the schema is applied (~T+45) and before the final deploy (~T+180).*
> Act as a skeptical staff engineer reviewing this. List the 3 riskiest assumptions and the 2 things that break under concurrency or on refresh.

**Screenshot critique** — *any time the UI looks off, and always the turn before prompt 13.*
> List the 5 visual defects that make this look like a tutorial app, ranked by how much they cheapen the product.

**Verification demand** — *whenever a reply says "should work" or claims success without pasted output.*
> Do not tell me it should work. Give me the exact command, run it, and paste its output in this turn. If you could not verify it, say "I could not verify this."

**Reflection draft** — *T+190, once, against DECISIONS.md — never against memory.*
> Read docs/DECISIONS.md and `git log --format='%h %s%n%b'`. Draft REFLECTION.md parts 1-4 only: (1) two things I'd do identically, with evidence; (2) three specific failures with elapsed cost in minutes and how I diagnosed them, including one where I was the problem; (3) where AI actively got in the way, named as failure modes; (4) what is still shaky and unfixed. Leave part 5 as a stub. Use only DECISIONS.md and the git log — invent nothing. Every claim carries a number, a filename, a sha or a verbatim quote. Banned words: "amazing", "incredible", "game-changer". Name at least one thing that is still broken.

**Bug card** — *fill this in before the diagnosis prompt. Re-fill from scratch after a two-strike reset (`git reset --hard` to the last green commit, `/clear`).*
```
Repro steps:
Expected vs actual:
Verbatim error + stack:
Console output:
Failing request — method / URL / status / body:
Last green commit sha:
```

---

# Log entries

Dictated to the agent at each correction moment (~25 seconds), appended to `docs/DECISIONS.md`, curated into `docs/PROMPT_LOG.md` at T+188. Never written retrospectively.

```
### T+mm — <short title>
Prompt (abridged): <the goal + out-of-scope lines only>
What came back:    <one or two sentences>
What was wrong:    <the defect, with the verbatim error or observed symptom>
What I changed:    <the follow-up prompt or pushback, and why — this is the graded field>
Cost:              <N min> · verified by <pasted output | deployed walkthrough | two-window test> · <sha>
```

An entry with an empty "What was wrong" is a slice that worked first try — log it anyway. A log where everything worked first try is not credible; a log where nothing did is not a plan.

_(empty — the sprint has not started)_
