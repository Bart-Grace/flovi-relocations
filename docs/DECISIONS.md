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
