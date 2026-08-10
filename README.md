# Flovi — relocation dispatch

**Dispatcher (web):** https://flovi-dispatcher-bl.vercel.app
**Driver (mobile):** https://flovi-driver-bl.vercel.app

Two connected apps. A dispatcher creates relocation requests; drivers see them and book
them in one tap. Both screens update live, without a refresh.

Built in one sitting, entirely AI-generated — no line of code was typed by hand.

---

## Architecture

```
apps/dispatcher-web/     Vue 3 · Vite · TypeScript · Tailwind v4
apps/driver-flutter/     Flutter web (CanvasKit), framed as a phone
        │                        │
        └──────── @supabase ─────┘
                     │
              Supabase (eu-north-1)
              Postgres · RLS · Realtime · Google OAuth
```

There is no backend service. Both clients talk to Postgres through PostgREST, and the
security boundary is row-level security evaluated against `auth.uid()`. Every state
transition that matters — booking, releasing, assigning — goes through a
`SECURITY DEFINER` function, never a client `UPDATE`.

## Booking is one guarded UPDATE

```sql
update public.relocation_requests r
   set driver_id = v_uid, status = 'booked', booked_at = now()
 where r.id = p_request_id and r.status = 'open'
   and r.driver_id is null and r.dispatcher_id <> v_uid;
if not found then raise exception 'This gig is no longer available'; end if;
```

That statement is the entire race protection. Under READ COMMITTED the losing transaction
blocks on the row lock, re-evaluates its `WHERE` against the committed row, matches nothing
and raises. No advisory lock, no `SELECT FOR UPDATE`, no client-side status check — checking
`status == 'open'` in the client before writing is a TOCTOU race that two simultaneous taps
walk straight through.

**Drivers have no `UPDATE` policy at all.** RLS is row-level, so any policy letting a driver
set `driver_id` would also let them rewrite `origin`, `destination` and `price_cents`.

## Why the publishable key is public

`sb_publishable_…` ships inside both bundles by design. It identifies the project; it grants
nothing. Every table has RLS enabled with per-verb policies scoped `to authenticated`, so the
real boundary is the JWT, not the key. The secret key, the Google client secret and the
database password never leave the operator's machine — see `.gitignore` and
`.claude/CLAUDE.md`.

## Run it

```bash
# Dispatcher
cd apps/dispatcher-web && npm ci
VITE_SUPABASE_URL=… VITE_SUPABASE_PUBLISHABLE_KEY=… npm run dev   # :5173

# Driver
cd apps/driver-flutter && flutter run -d chrome \
  --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…

# Deploy — each script prints exactly one line: the production alias
./scripts/deploy-web.sh
./scripts/deploy-driver.sh
```

The schema lives in `supabase/migrations/`. Apply `0001_init.sql` then
`0002_dispatcher_assignment.sql`; each block ends in its own verification query.

## Deliberately not built

No role model — "driver" is any other profile, because a roles table was not needed to prove
the workflow. No release UI for the dispatcher beyond unassign, no detail pages, no search or
filters, no maps, no attachments, no push notifications, no earnings, no automated test suite.
The correctness story is a manual two-window test: two drivers, one gig, one winner and one
`This gig is no longer available`.
