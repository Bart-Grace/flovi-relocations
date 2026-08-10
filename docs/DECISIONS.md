# Decisions log

Dictated at the moment each decision was made, never written retrospectively.
Curated into `docs/PROMPT_LOG.md` at T+188; parts 1–4 of `REFLECTION.md` are drafted from this file and
`git log` only.

Entries below the T+0 marker predate the first line of application code — they are Phase 0 infrastructure
decisions, so they carry no prompt and no sha.

---

### T+0 — Rejected a custom PHP/Node API; kept Supabase

**Question raised:** why use Supabase at all instead of writing a small PHP API?

**What was wrong:** nothing yet — this was a challenge to the plan's premise, before any code existed.

**What I decided and why:** kept Supabase. Three costs killed the custom API, none of them the CRUD:
OAuth session handling would have to be written twice (TypeScript and Dart) where the SDKs give session
restore, auto-refresh and an auth-state stream for free; PHP has no first-class realtime, so the realistic
landing point is a 5-second poll — which is already this plan's *fallback* for a dead socket (§8, T+165);
and Vercel does not run PHP first-class, adding a whole second deployment axis. Decisive argument: none of
the five scored rows in `task.md` is backend architecture, so the swap buys nothing and spends minutes
against the one hard constraint, delivery.

**What the pushback produced instead:** a standing rule adopted before any client code existed — **every
mutation ends with `.select()`, and an empty result is an error, never a success.** This is the cheap
mitigation for the one property of this stack I distrust: RLS rejections are silent (HTTP 200 + empty
array, `plan.md` §6 trap 10, budgeted at 30 min). Recorded in full in `REFLECTION.md` §0.

**Cost:** 0 min — decided before the clock.

---

### T+0 — The planned Vercel project names were already taken

**What was wrong:** `plan.md` §1 reserves `flovi-dispatcher` and `flovi-driver`. Both already returned
HTTP 200 with fully built applications on them — a Vite bundle titled *Flovi Dispatcher* and a Flutter web
shell. Not ours: the dispatcher bundle points at `https://csgjodwphnajokraoayu.supabase.co`, a different
Supabase project from ours (`wzryktarwyjyryriqfyd`), and `vercel whoami` showed we were not even logged in.
Almost certainly another candidate on the same brief taking the obvious names.

**How I caught it:** the plan's own T+5 checkpoint says "both origins return 200 in incognito". They
returned 200 *before we had deployed anything* — a passing checkpoint that should have been impossible.
Grepping the deployed bundle for `*.supabase.co` settled ownership in one command.

**What I changed:** renamed to `flovi-dispatcher-bl` / `flovi-driver-bl`. `*.vercel.app` subdomains are
globally unique and cannot be reclaimed, so there was no alternative. Caught at T+0, this cost a rename;
caught at T+50 it would have cost a rename **plus** rewriting both allow-lists and waiting out Google's
origin propagation a second time.

**Sharp edge worth keeping:** HTTP 404 on a candidate name proves only that nothing is deployed there, not
that the project name is free. The real proof is `vercel link --yes --project <name>` succeeding — which,
confirmed here, does create the project when the name is available (`plan.md` §10 item 10a).

**Cost:** ~8 min · verified by `vercel project ls` listing both under scope `flovi`, and both aliases
returning 200.

---

### T+0 — The direct database host is IPv6-only and unreachable

**What was wrong:** `plan.md` §4 live-verification step 3 requires two `psql` terminals on the direct,
non-pooled connection to prove `book_request`'s race behaviour. Verbatim failure:

```
psql: error: could not translate host name "db.wzryktarwyjyryriqfyd.supabase.co" to address:
nodename nor servname provided, or not known
```

`host db.<ref>.supabase.co` returns an AAAA record only. This machine has no IPv6 route.

**What I changed:** switched to the session pooler, `aws-0-eu-north-1.pooler.supabase.com:5432`, user
`postgres.<ref>`. Port matters: **session** mode (5432) holds an open transaction across statements, which
is the only property the double-booking test needs; transaction mode (6543) would not. Region was found by
attempting the connection against each EU pooler until one authenticated, rather than guessing.

**Second-order benefit:** with working `psql`, the migration can be applied from a file and all four
verification queries run and diffed automatically, instead of pasting four blocks into the SQL editor and
eyeballing the results.

**Cost:** ~6 min · verified by `select count(*) from auth.users` returning 3 over the pooler.

---

### T+0 — Vercel CLI 58.9.0 changed the shape of deploy stdout

**What was wrong:** `plan.md` §5 captures the deploy URL with `url="$(vercel deploy --prod --yes)"`. The
installed CLI prints the per-deploy URL **and** a trailing JSON summary block on stdout, so that capture
returns the whole blob. The script would have printed a JSON object where the README expects a URL —
and `plan.md` §6 trap 9 marks a driver-URL mismatch as fatal.

**How I caught it:** reading the actual output of the reservation deploy rather than trusting the plan's
transcription of it.

**What I changed:** both scripts now send the CLI's own output to stderr and print the known production
alias as the final stdout line. Fixed in `plan.md` §5 and in prompt 04 before either script was generated.

**Cost:** ~2 min · verified by the reservation deploys of both projects.

---

### T+0 — A hand-opened authorize URL returns implicit tokens, not `?code=`

**What was wrong:** nothing — but `plan.md` §2 step 6 states the T+25 proof is landing on `?code=…`, and
the actual landing was `#access_token=…&refresh_token=…`.

**Why:** opening `/auth/v1/authorize` by hand starts a flow with no `code_challenge`, so Supabase returns
the implicit response in the URL fragment. `?code=` appears only once an SDK initiates PKCE — which is the
flow the plan was describing. The manual test is not wrong, it is a different flow.

**Why it did not matter:** decoding the returned JWT proved more than `?code=` would have — `sub`,
`email`, `role: authenticated`, `provider: google`, and both `full_name` and `avatar_url` present in
`user_metadata`, which are exactly the two fields `handle_new_user()` reads.

**One real error on the way there:** `error_code=bad_oauth_state`, *OAuth state has expired* — a stale
authorize link left open past its TTL. Retrying on a fresh tab fixed it. Worth noting because the error
arrives back at the app URL, which by itself already proved Google was not blocking the consent screen.

**Cost:** ~4 min · verified by three rows in `auth.users`, each with `full_name` and `avatar_url`.

---

### T+45 — The data contract, applied and raced (prompt 02)

**Prompt (abridged):** one migration, four blocks A–D, each ending in its own verification query. Out of
scope: no enum types, no roles table, no DELETE policy, no seed script, no generated types, no client code.

**What came back:** `supabase/migrations/0001_init.sql` ran top to bottom with `ON_ERROR_STOP=1` and exit 0.

**What was wrong:** nothing in the SQL — this slice worked first try. One shell defect on the way: the
connection arguments were held in a variable and passed unquoted, which works in bash but **not in zsh**,
where unquoted parameter expansion is not word-split. `psql` received one 90-character hostname and failed
with `could not translate host name " aws-0-... -p 5432 -U ..."`. Inlining the arguments fixed it. Worth
recording because the error text points at DNS and the cause is the shell.

**Verified, not assumed** — all four verification queries matched the expected lines exactly:
`profiles | 5` and `relocation_requests | 13` · six policies, every `relrowsecurity = t`, every role
`{authenticated}`, no `ALL`, no `DELETE` · both functions `prosecdef = t`,
`proconfig = {"search_path=\"\""}`, `auth_exec = t`, `anon_exec = f` ·
`supabase_realtime | public | relocation_requests`.

**The race, proven live rather than reasoned about.** Two concurrent `psql` sessions on the session pooler,
each setting `request.jwt.claims` to a different driver and calling `book_request` on the same row. Driver A
committed `booked`; Driver B blocked on the row lock, re-evaluated after the commit, matched nothing and
raised verbatim:

```
ERROR:  This gig is no longer available
CONTEXT:  PL/pgSQL function public.book_request(uuid) line 18 at RAISE
```

This settles the last open assumption in the plan — that READ COMMITTED gives the guarded UPDATE its
atomicity — with an observation instead of a citation.

**One thing worth naming.** The dispatcher-books-own-gig guard (`dispatcher_id <> v_uid`) raises the *same*
message as a lost race. Confirmed by calling it as the dispatcher. That ambiguity is exactly why the demo
needs three Google accounts: on two accounts the double-booking scene would pass for the wrong reason, and
that is a question I could not answer honestly on stage.

**Cost:** ~14 min · verified by the four queries, the two-session race, and a `release_request` round trip
that returned the row to `open` and left the database clean for the demo.

---

### T+50 — "Latest" was the wrong pin: TypeScript 7 breaks vue-tsc (prompt 03)

**Prompt (abridged):** running Vite + Vue 3 + TS app with Tailwind v4 and a Supabase client, one signed-out
placeholder. Out of scope: no auth flow, no router, no Pinia, no UI library.

**What was wrong:** `npm run build` died before compiling anything:

```
Error [ERR_PACKAGE_PATH_NOT_EXPORTED]: Package subpath './lib/tsc' is not defined by "exports"
in node_modules/typescript/package.json
```

**Root cause:** the pins in `CLAUDE.md` came from `npm view <pkg> version` — the newest published version of
each package, resolved independently. That produced `typescript 7.0.2`, which restructured the package and
no longer exports `./lib/tsc`; `vue-tsc` 3.3.9 requires exactly that path. Its declared peer range,
`typescript: '>=5.0.0'`, is optimistic and does not describe reality.

**How I diagnosed it:** the stack trace named `vue-tsc/index.js` calling `require.resolve` on a typescript
subpath, so the failure was a package-layout mismatch, not our code. Confirmed by walking majors downward —
6.0.3 works, 7.0.2 does not — instead of guessing.

**What I changed:** pinned `typescript 6.0.3` exactly, no caret, and recorded the reason in `CLAUDE.md` so a
later "upgrade to latest" does not silently reintroduce it. This is the failure mode of resolving each
dependency's newest version in isolation: individually current, jointly incompatible.

**Verified:** `npm run build` green · dev server answers 200 on :5173 with `<title>Flovi · Dispatcher</title>` ·
`min-h-dvh`, `brand-950`, `tracking-widest` and `rounded-sm` all present in the emitted CSS, so Tailwind v4 is
compiling · a build with `VITE_SUPABASE_URL` unset ships the string `VITE_SUPABASE_URL` and
`Configuration missing` into the bundle — the boot guard names the variable instead of rendering white.

**Cost:** ~9 min · verified by pasted build output, an HTTP 200 from the dev server, and greps of the emitted
bundle.

---

### T+55 — The deploy script's stdout contract leaked, and I had blamed the wrong command (prompt 04)

**Prompt (abridged):** two idempotent deploy scripts, each printing the stable production alias as its final
stdout line. Out of scope: no CI, no GitHub Actions, no git-connecting the Flutter project.

**What was wrong:** the script printed 20 lines on stdout instead of one. I had already corrected the plan
for this class of bug — Vercel CLI 58.x appends a JSON summary to stdout — and had redirected
`vercel deploy` to stderr. The redirect worked. The noise was `npm ci && npm run build`, which I had never
considered because I was looking for the failure I already knew about.

**How I caught it:** asserting the contract instead of eyeballing the output — counting the lines on stdout
and requiring exactly 1. Reading it would have shown a URL on the last line and looked correct.

**What I changed:** `npm ci >&2 && npm run build >&2`, and the same treatment for `flutter build web` in
`deploy-driver.sh` before that script had ever run. The contract is now stated in a comment in both files:
stdout is exactly one line, the production alias.

**Worth naming as a failure mode:** having a correct hypothesis made me stop looking. The fix for the known
trap was right; the check that caught the unknown one was mechanical, not clever.

**Verified:** stdout is 1 line, `https://flovi-dispatcher-bl.vercel.app` · anonymous `curl` returns 200 ·
deep link `/requests/abc` returns 200, so the SPA rewrite is live · the deployed bundle contains
`https://wzryktarwyjyryriqfyd.supabase.co`, so the build-time env inlining reached production.

**Cost:** ~7 min · verified by a line count, three HTTP status codes, and a grep of the deployed bundle.

---

### T+65 — Two instructions in the plan were wrong about the SDK; reading it settled both (prompt 06)

**Prompt (abridged):** a deployed Flutter web app where a second Google account signs in and reaches an empty
two-tab shell. Out of scope: no gig list, no booking, no queries of any kind.

**What was wrong — first:** the plan specifies `signInWithOAuth(..., webOnlyWindowName: '_self')`. That named
parameter **does not exist** in `supabase_flutter` 2.17.1. Reading the signature, the only options are
`redirectTo`, `scopes`, `authScreenLaunchMode` and `queryParams`. Reading one level deeper, the SDK's private
`_launchAuthUrl` already hardcodes `webOnlyWindowName: '_self'` — the instruction was describing behaviour
that is now the library's, not the caller's. Dropped it.

**What was wrong — second:** the plan treats `redirectTo` as optional on web. It is not, here. With no
`redirectTo`, Supabase falls back to the Site URL, which is the **dispatcher** app — a driver signing in
would land in the wrong product with a valid session, and nothing would look broken. Passing
`kIsWeb ? Uri.base.origin : ...` fixes it, and that origin is already in the Supabase allow-list.

**Third, in our favour:** `Supabase.initialize` accepts `publishableKey` directly in this version, so no
`anonKey` fallback was needed.

**Service worker, prevented rather than mitigated.** The plan's advice for trap 14 is "verify every driver
deploy in fresh incognito", with stripping the registration as a 2-minute fix. I did the fix first: the
custom bootstrap calls `_flutter.loader.load({onEntrypointLoaded})` with **no** `serviceWorkerSettings`, and
the registration path in the loader is entered only when that key is present — confirmed by reading the
emitted bundle, not by trusting the omission. The same callback removes the branded loader at the right
moment, so there is no white flash while the engine boots.

**One deletion worth declaring:** `test/widget_test.dart`, the scaffold's counter-app test, referenced a
`MyApp` class that does not exist here and was the only thing `flutter analyze` complained about. It tested
nothing in this project. Removed rather than repaired — there is no automated suite in this build, and the
correctness story is the two-window booking test.

**Verified:** `flutter analyze` clean · release build green with the default CanvasKit renderer, no
`--web-renderer`, no `--wasm` · `deploy-driver.sh` stdout is 1 line · the deployed URL and a deep link both
return 200 anonymously · `vercel project ls` shows exactly two projects, so the fatal trap-9 duplication did
not happen · the deployed `main.dart.js` contains the Supabase URL, so `--dart-define` reached the bundle.

**Cost:** ~18 min · verified by pasted analyzer and build output, four HTTP status codes, and greps of the
deployed bundle.

---

### T+82 — My own verification produced a false negative (prompt 07)

**Prompt (abridged):** the dispatcher's main screen — persistent shell plus a list of my requests with
colour-coded status pills. Out of scope: no create form, no edit, no realtime, no filters, no delete.

**Two real defects, then one imaginary one.**

**Real, first:** `vue-tsc` rejected the query result — `Conversion of type 'GenericStringError[]' to type
'RelocationRequest[]' may be a mistake`. Without generated database types, supabase-js cannot infer a
column list that is assembled at runtime, so it degrades to an error type. A cast would have silenced it and
thrown away every remaining guarantee about that row shape. Used `.returns<RelocationRequest[]>()` instead,
which states the intent at the query rather than laundering it afterwards.

**Imaginary, second — and this is the one worth writing down.** Checking the deployed CSS for the five pill
colours reported all five missing, plus `animate-pulse`. That reads like Tailwind failing to scan the class
strings out of the TypeScript object in `StatusPill.vue`, which is a real and known v4 failure mode. It was
not happening. The local `dist/` contained every class. The production fetch had pulled `index.html` from
the CDN with `x-vercel-cache: HIT` — a **stale** HTML that still pointed at a previous CSS filename. Fetching
with cache-control headers revealed a different asset hash, and that file contained all six classes.

**What I take from it:** a verification step is code, and it fails the same ways code does. This one failed
in the direction that manufactures work — it accused a component that was correct. Two habits fixed it:
comparing the locally built asset hash against the one production actually references, and bypassing the
CDN cache when asserting anything about a just-deployed file.

**Incidental finding, kept:** local and Vercel builds are not byte-identical — 20354 vs 21056 bytes of CSS
for the same commit, because Vercel rebuilds from source in its own environment. So `npm run build` locally
is a fast-fail check, not evidence of what shipped. Every assertion about production is made against
production.

**Verified:** build green · the CSS that production actually serves contains all five status colours, the
skeleton animation and the brand tokens · no banned default present in `src/` — no `bg-gray-100`, no
`shadow-md`, no bare `<table>`, no `alert()`/`confirm()`, no literal "Loading..." (the only greps that hit
were my own comments naming the ban).

**Cost:** ~16 min, of which ~5 were spent on a defect that did not exist.

---

### T+90 — One missing slash sent every driver into the dispatcher app

**Symptom, as reported:** signing in on the driver app showed "Continue with Google" **twice**, and the
second screen led to the dispatcher's request table. No error anywhere, in either app.

**Root cause:** the Supabase redirect allow-list entry is `https://flovi-driver-bl.vercel.app/**`. That glob
does not match a **bare origin** — and `Uri.base.origin` in Dart, like `window.location.origin` in the
browser, returns no trailing slash. Supabase rejected the target and fell back to the Site URL, which is the
dispatcher. The driver ended up in the wrong product holding a completely valid session.

**Proved before changing anything**, by driving the allow-list from the outside — start a flow, capture the
`state` Supabase issued, then return to `/callback` with an error and read where it sends us:

```
https://flovi-driver-bl.vercel.app/   (with slash)  ->  https://flovi-driver-bl.vercel.app/
https://flovi-driver-bl.vercel.app    (no slash)    ->  https://flovi-dispatcher-bl.vercel.app
```

**The part that matters more than the fix.** The *dispatcher* has the identical bug — it also passed a bare
`window.location.origin`. It is invisible there for one reason only: the fallback destination happens to be
the dispatcher itself. A silently wrong value that coincides with the right answer in the app you test first,
and is fatal in the app you test second. Both were fixed; neither would have been found by testing the
dispatcher.

**Why the code fix, not the console fix.** Adding the bare origin to the allow-list would also have worked
and taken one click. The trailing slash is better: it is one place per app, needs no console round trip and
no Google/Supabase propagation wait, and it leaves the allow-list stating exactly one shape per origin
instead of two.

**Two shell defects on the way, both zsh-specific and both misleading:** earlier, unquoted parameter
expansion is not word-split in zsh, so `psql` received one giant hostname and reported a DNS failure. Here,
`for path in ...` clobbered `PATH` itself — `path` is tied to `PATH` in zsh — and the loop reported
`command not found: curl`. Both errors pointed at the environment; both causes were the shell.

**Verified:** the allow-list probe above · `flutter analyze` clean · the deployed `main.dart.js` hashes
byte-identical to the locally built file, so production is running exactly the audited artifact.

**Cost:** ~11 min · verified by the callback probe and a SHA-256 comparison against production.

---

### T+100 — TypeScript said string, Vue made it a number (prompt 08)

**Prompt (abridged):** create and edit a relocation request from a right-hand slide-over, with the list
reflecting the save. Out of scope: no realtime, no optimistic UI, no focus trap, no assigning a driver.

**What was wrong:** the first real submission failed with a toast reading
`S.value.replace is not a function`.

**Root cause:** `const priceEuros = ref('')` infers `Ref<string>`, so `priceEuros.value.replace(',', '.')`
type-checks and `vue-tsc` passes. But Vue 3 applies the **`.number` modifier automatically** to
`<input type="number">`, so the moment the user types, the ref holds a `number`. The static type and the
runtime value disagree, and nothing in the toolchain can see it: the cast happens inside Vue's v-model
compilation, below TypeScript's view.

**How it was caught:** by submitting the form in a browser against production. `vue-tsc --noEmit`, the
build, and every structural grep were green. A type system that is lied to reports no error.

**What I changed:** typed the ref `string | number` — with the reason on the line above it, because
`ref('')` is what anyone would write next time — and normalised with `String(...)` before parsing.

**What went right, and is worth more than the bug.** The failure surfaced as a toast carrying the verbatim
message, and **the panel stayed open** — the half-filled form was still there. That is the behaviour prompt
08 specified for a rejected write, and it was exercised for real by an accident rather than by a drill.

**One acceptance criterion could not be tested through the UI.** "A CHECK violation surfaces as a toast" was
not reachable from the form: the price input carries `min="0"`, so the browser blocks a negative value before
any request is made. The constraint itself was verified directly against the database, which rejects it —
`violates check constraint "relocation_requests_price_cents_check"`. Defence in depth, but stated plainly
rather than ticked off.

**Verified in production, as Driver A signing into the dispatcher app** — an account with zero rows, which
also exercised the empty state: icon, one line, CTA · create → row appears as `Gdańsk → Hamburg` with an
amber **Open** pill, `450,00 €`, and a confirming toast · edit → destination becomes `Rotterdam` and the row
text changes · cancel → the pill turns zinc **Cancelled** and **the row still exists**; a query confirms
three rows and no deletion anywhere · `price_cents` stored as `45000`, so the euro-to-cents conversion is
right.

**Cost:** ~21 min · verified by browser interaction against production and a SQL read-back.

---

### T+125 — Realtime worked first try, because the order was treated as the specification (prompt 09)

**Prompt (abridged):** the dispatcher list patches itself when a row changes from another client, with no
refresh. Out of scope: no presence, no broadcast, no reconnect UI, no RLS changes, no Flutter changes.

**What was wrong:** nothing. This is the slice the plan budgets the most time for and reserves an entire
fallback branch for — a five-second poll — and it delivered events on the first attempt.

**Why, specifically.** The failure mode here is not subtle code, it is order. supabase-js does not hand the
session token to the Realtime socket by itself, so a channel created before `setAuth` reports `SUBSCRIBED`
and delivers nothing: a socket that looks healthy in every way except that no events arrive. The sequence
was written as the contract of the composable, with the reason for each step next to it —
`getSession()` → `realtime.setAuth(token)` → re-auth on `TOKEN_REFRESHED` → *only then* create the channel,
in `onMounted` → `removeChannel` in `onUnmounted` — and the channel is never created at module scope, where
it would run before the session is restored from storage.

The second trap, three toasts per booking, is prevented by the same discipline: `supabase.channel('name')`
called twice creates a **second** channel rather than returning the existing one, so there is exactly one
channel per concern, created on mount and removed on unmount.

**Verified live against production, without touching the browser between cause and effect.** With the
dispatcher list open, `book_request` was called from `psql` as Driver B — the same RPC the driver app calls,
so the path under test is identical. The row's pill went from amber **Open** to blue **Booked**, Driver B's
avatar and name faded in underneath the route, and **exactly one** toast appeared reading
*"Driver B booked Gdańsk → Rotterdam."* No refresh, no refetch — the handler patches the array in place.

**A negative result worth as much as the positive one:** releasing the gig, which is also an UPDATE on the
same row, produced a silent patch and **no toast**. The money-shot condition is a transition — `driver_id`
going from empty to set — not merely "an update happened". Without that, every edit would announce itself.

**Cost:** ~19 min · verified by a live booking driven from SQL while the deployed page sat untouched.

---

### T+137 — The last open assumption resolved, and a default that runs the other way (prompt 10)

**Prompt (abridged):** the Available tab lists open gigs and updates itself live. Out of scope: no booking
action, no My gigs tab, no search, no filters, no map, no pull-to-refresh, no detail page.

**The assumption this slice existed to settle.** `plan.md` §10 item 5 asked whether `supabase_flutter`
auto-propagates the JWT to the Realtime socket the way supabase-js does **not** — and warned against assuming
symmetry. The plan deliberately puts the read stream before booking so that, if the answer were no, it would
surface on a path with no write consequences. **Answer: yes, it does.** The list populated and stayed live
with no `setAuth` call anywhere in the Flutter app. The two SDKs genuinely differ here, and the only way to
know was to run it.

**What was wrong:** the first deploy listed gigs in the wrong order — 12 Dec above 12 Aug. `.order()` in the
Dart client defaults to **descending**, the opposite of supabase-js, so `ascending: true` is not redundant
noise but the whole behaviour. A driver looking for the next job wants the soonest pickup first; the
descending list is subtly, plausibly wrong, which is the kind of defect that survives a demo.

**A refusal designed away rather than handled.** `book_request` rejects a dispatcher booking their own gig,
and it raises `This gig is no longer available` — the correct refusal with a misleading message. Instead of
special-casing that error, gigs the current user dispatched are filtered out of the list, so the button is
never offered. This is also the prompt's own rule in action: `.stream()` accepts exactly one filter on one
column, so `status = 'open'` goes server-side and the second condition is a client-side `.where()`.

**Verified in production:** the deployed driver URL listed three open gigs with route icon, date, price and
an amber Open chip · a row inserted from SQL appeared **with no reload**, in the correct sorted position ·
after the fix, order reads 12 Aug, 14 Aug, 16 Aug, 12 Dec · `flutter analyze` clean.

**Cost:** ~17 min · verified by two live inserts against the deployed app.

---

### T+148 — A filtered stream never tells you a row left the filter (prompt 11)

**Prompt (abridged):** one tap books a gig, with a confirmation step and a truthful failure path. Out of
scope: no release UI, no optimistic removal, and **no client-side status check of any kind**.

**What was wrong:** the booking succeeded — SnackBar confirmed it, and the database showed
`Wrocław → Prague | booked | drivera.flovi@gmail.com` — but the gig **stayed in the Available list**.

**Root cause, from reading the SDK rather than guessing.** In `supabase_stream_builder.dart`, stream filters
are converted into a `PostgresChangeFilter` on the realtime subscription, so `.eq('status', 'open')` is
evaluated **by the server**. And the UPDATE branch only ever replaces an existing record or appends a new
one — it never removes. Put together: an UPDATE that moves a row *out* of the filter does not match the
subscription, is never delivered, and the client never learns the row is gone. It sits in the local cache
until a reload.

**Why the obvious fix was the wrong one.** Removing the row by hand after a successful booking would have
taken one line. The prompt forbids exactly that — "the row leaves the list via the stream, not manual
removal" — and the constraint is right: a manual removal fixes the list for the driver who tapped, and
leaves it stale for every other driver looking at the same gig, which is the case that matters.

**What I changed:** dropped the server-side filter entirely. The stream now carries every change to the
table and the whole predicate — `status == 'open' && dispatcherId != me` — is evaluated client-side. More
events over the wire, and the only shape in which a row can leave the list *through the stream*.

**Deliberately absent, and worth stating:** there is no `status == 'open'` check anywhere on the write path.
Reading the row and checking it in Dart before calling the RPC is a time-of-check/time-of-use race — two
drivers tapping in the same second both read `open`, both pass, both write. The guard is the single
conditional UPDATE inside `book_request` and nowhere else. The client-side filter above decides what to
*display*; it never decides whether a booking may proceed.

**Verified in production:** bottom sheet, not an AlertDialog, showing route, pickup, payout and notes · the
confirm button disables and shows a spinner while the call is in flight, so a double tap cannot become two
RPC calls · after confirming, the SnackBar read "Booked Wrocław → Prague." and the row **left the list on
its own** · the database confirms `booked` with the right driver and a non-null `booked_at`.

**Cost:** ~24 min · verified by booking through the deployed app and reading the SDK source to explain the
first failure.

---

### T+155 — The two-window double-booking test, through real UI

**What was tested:** the correctness story of the whole build, and the only manual test in it, since there
is no automated suite.

**Setup, deliberately harsher than "two taps in the same second".** Driver A opened the booking sheet for
`Kraków → Vienna` and left it open. Driver B — a different Google account in a different Chrome profile —
then booked that same gig through the real app: SnackBar "Booked Kraków → Vienna.", row gone from his list.
Driver A's list updated too: the gig disappeared **behind his still-open sheet**. Then Driver A confirmed.

**Result, verbatim from the deployed app:**

```
This gig is no longer available
```

**Why this framing proves more than simultaneous taps.** At the moment Driver A pressed Confirm, his own
client already knew the gig was gone — it had left his list seconds earlier — and the button was still
there offering to book it. The refusal did not come from any client-side state. It came from the guarded
UPDATE inside `book_request` matching zero rows. Had the protection been a `status == 'open'` check in Dart,
this exact sequence would have sailed through it: the check would have read stale data, or been skipped
entirely because the row was no longer in the local list.

The message reached the driver unmodified because the repository does not translate `PostgrestException`.
The sentence a driver reads is the sentence written next to the guard that produced it, in
`0001_init.sql` — one string, one source, no drift.

**Cost:** ~12 min · verified across two Chrome profiles and two Google accounts against production.

---

### T+165 — My gigs, and the same trap declined on purpose (prompt 12)

**Prompt (abridged):** a My gigs tab listing this driver's booked gigs, live. Out of scope: no release
action, no detail page, no history filter, no chat, no ratings, no earnings.

**The interesting decision is what I did *not* change.** Prompt 11 had just forced the Available list's
filter client-side, because `SupabaseStreamBuilder` pushes stream filters onto the realtime subscription and
its UPDATE branch never removes a record — so a row leaving the filter is silently never reported. The
reflex is to apply that everywhere. Here the server-side `.eq('driver_id', uid)` is kept, because a row can
only leave *this* filter if `driver_id` is cleared, and the only thing that clears it is `release_request`,
which has no UI in this build. A dispatcher cancelling a booked gig sets `status = 'cancelled'` and **keeps**
the driver — that is what the `booked_requires_driver` CHECK was written to allow — so the update stays
inside the filter and arrives normally.

The condition under which this becomes a bug is written next to it: if a release button is ever added, the
filter has to move client-side for exactly the reason it did in the Available list. A pattern applied
without its precondition is how a fix becomes cargo cult.

**Verified in production:** Driver A's My gigs showed **only** `Wrocław → Prague`, the gig he booked;
`Kraków → Vienna`, booked by Driver B minutes earlier, was absent — the isolation the broad SELECT policy
plus UI filtering is supposed to produce · booking a second gig for Driver A from SQL made it appear in the
tab **with no reload**, sorted into the right position · the empty state is an illustrated widget with one
line of copy and a CTA back to Available, never `Text('No gigs')` · `flutter analyze` clean, and the now
dead `_EmptyTab` placeholder was deleted rather than left behind.

**Cost:** ~13 min · verified against production on two accounts.

---

### T+185 — Design pass, and the defect only a booked row could reveal (prompt 13)

**Ranked critique of the deployed dispatcher board, before touching anything:**

1. **The left rail was a stub** — 46px holding a logo tile and one non-functional icon. A navigation rail
   with a single dead item does not merely look unfinished, it *advertises* the features that do not exist.
2. **Column headers missed their columns.** `PICKUP` sat at x≈935 with its values at 953; `PRICE` at 1039
   with values ending at 1094. `RequestList`'s header used `minmax(0,1fr) 7rem 6rem 5.5rem` while
   `RequestRow` used `… auto`. Two grid definitions for one table. A 6–18px drift nobody can name but
   everybody reads as sloppy.
3. **A booked row was indistinguishable except for a pill ~800px from the route** — and that row is exactly
   what the camera points at during the money shot.

**Fixed, in that order:** the rail is gone and the brand mark moved into the topbar, where it costs nothing
and claims nothing · one grid template, duplicated verbatim with a comment in both files saying they must
stay identical · rows that are no longer open carry a left accent bar in their status colour, so the flip is
visible from across the room rather than findable by reading.

**A regression I caused and caught.** Giving Status a fixed column width made the pill stretch to fill it —
grid items justify to `stretch` by default — turning a badge into a wide box. `justify-self-start` restored
it. Worth recording because the fix for defect 2 created defect 6, and only re-screenshotting after the
change found it.

**The defect that only appeared once a row was booked.** With four fixtures inserted in a single statement
they share a `created_at` to the microsecond, and the list ordered by `created_at desc`. Postgres may return
ties in any order, so the moment one row was UPDATEd it **jumped to the bottom of the list**. During the
money shot a gig would appear to leap position the instant a driver takes it — indistinguishable from a bug,
on camera. The list now orders by `pickup_date` ascending with `id` as a deterministic tiebreaker, which
also makes the dispatcher board agree with the driver app when the two sit side by side.

None of this was visible while every row was Open. The critique was done on a screenshot of the real
deployed board, and the last defect only surfaced after booking one row to check the accent colour.

**Cost:** ~22 min · verified by re-screenshotting production after each change.

---
