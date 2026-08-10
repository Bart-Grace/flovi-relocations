-- 0001_init.sql — the whole data contract in one migration.
-- Blocks A-D run top to bottom with zero edits. Each block ends in its own verification query.
-- Schema + RLS + RPC are one slice because they are one contract: split them and you get a policy
-- set that contradicts the function it was written for.

-- ============================================================================
-- A: schema
-- ============================================================================

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text, full_name text, avatar_url text,
  created_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: AFTER INSERT never fires retroactively, and the three demo accounts signed in during
-- Phase 0, before this trigger existed. Idempotent, so it is safe to re-run after any later sign-in.
insert into public.profiles (id, email, full_name, avatar_url)
select id, email, raw_user_meta_data->>'full_name', raw_user_meta_data->>'avatar_url'
from auth.users on conflict (id) do nothing;

create table public.relocation_requests (
  id uuid primary key default gen_random_uuid(),
  dispatcher_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  origin text not null, destination text not null, pickup_date date not null,
  notes text, vehicle_type text,
  price_cents integer not null default 0 check (price_cents >= 0),
  status text not null default 'open' check (status in ('open','booked','in_transit','completed','cancelled')),
  driver_id uuid references public.profiles (id) on delete set null,
  booked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booked_requires_driver check (  -- 'cancelled' is terminal from any state: a booked gig keeps its driver when cancelled
    (status = 'open' and driver_id is null) or (status = 'cancelled') or
    (status in ('booked','in_transit','completed') and driver_id is not null)),
  constraint driver_implies_booked_at check ((driver_id is null) = (booked_at is null))
);

create index relocation_requests_dispatcher_idx on public.relocation_requests (dispatcher_id, created_at desc);
create index relocation_requests_open_idx on public.relocation_requests (status, pickup_date) where status = 'open';
create index relocation_requests_driver_idx on public.relocation_requests (driver_id) where driver_id is not null;

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end; $$;

create trigger relocation_requests_touch before update on public.relocation_requests
  for each row execute function public.touch_updated_at();

-- verify A — expect exactly two rows: profiles | 5 and relocation_requests | 13
select table_name, count(*) as cols from information_schema.columns
where table_schema = 'public' and table_name in ('profiles','relocation_requests')
group by table_name order by table_name;

-- ============================================================================
-- B: RLS. Every policy `to authenticated`; every auth.uid() written as (select auth.uid())
-- so it is cached per statement, not re-evaluated per row. Split per verb, never `for all`.
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.relocation_requests enable row level security;

-- broad on purpose: the dispatcher renders the booking driver's avatar and name — the money shot depends on it
create policy "profiles_select_all"  on public.profiles for select to authenticated using (true);
create policy "profiles_insert_self" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "profiles_update_self" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- deliberately broad: Realtime evaluates this SELECT policy against the NEW row, so a narrower predicate
-- silently drops the post-booking UPDATE for every driver who is not the booker. Reads are open to
-- authenticated and the UI filters; the write policies below stay strict.
create policy "requests_select_all"  on public.relocation_requests for select to authenticated using (true);
create policy "requests_insert_own"  on public.relocation_requests for insert to authenticated
  with check (dispatcher_id = (select auth.uid()));
create policy "requests_update_own"  on public.relocation_requests for update to authenticated
  using (dispatcher_id = (select auth.uid())) with check (dispatcher_id = (select auth.uid()));

-- NOTE: drivers get no UPDATE policy at all. Booking is RPC-only.

-- verify B — expect exactly six rows; relrowsecurity = t everywhere; every roles = {authenticated};
-- no cmd = ALL; no DELETE row on either table
select c.relname, c.relrowsecurity, p.policyname, p.cmd, p.roles
from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  left join pg_policies p on p.schemaname = 'public' and p.tablename = c.relname
where c.relname in ('profiles','relocation_requests') order by c.relname, p.policyname;

-- ============================================================================
-- C: booking RPCs. security definer + empty search_path, every identifier fully qualified.
-- auth.uid() still works under an empty search_path because it reads the request JWT GUC — do not "fix" it.
-- ============================================================================

create function public.book_request(p_request_id uuid) returns public.relocation_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_row public.relocation_requests;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  -- ATOMICITY: the guarded UPDATE below is the entire race protection. Under READ COMMITTED the losing
  -- transaction blocks on the row lock, re-evaluates its WHERE against the committed row, matches nothing
  -- and gets NOT FOUND. No advisory lock, no SELECT FOR UPDATE, no SERIALIZABLE.
  -- COLUMN SCOPING: RLS is row-level only, so any driver UPDATE policy would also let a driver rewrite
  -- origin, destination or price_cents. GRANT UPDATE(col) is Postgres's only column-level control and it
  -- breaks SELECT *. Hence no driver UPDATE policy anywhere: booking goes through this function.
  update public.relocation_requests r
     set driver_id = v_uid, status = 'booked', booked_at = now()
   where r.id = p_request_id and r.status = 'open'
     and r.driver_id is null and r.dispatcher_id <> v_uid
  returning r.* into v_row;
  if not found then raise exception 'This gig is no longer available' using errcode = 'P0001'; end if;
  return v_row;
end; $$;

create function public.release_request(p_request_id uuid) returns public.relocation_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_row public.relocation_requests;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  update public.relocation_requests r
     set driver_id = null, status = 'open', booked_at = null
   where r.id = p_request_id and r.driver_id = v_uid and r.status = 'booked'
  returning r.* into v_row;
  if not found then raise exception 'This gig is not yours to release' using errcode = 'P0001'; end if;
  return v_row;
end; $$;

-- Postgres grants EXECUTE to PUBLIC by default; take it back before handing it out.
revoke all on function public.book_request(uuid)    from public, anon;
revoke all on function public.release_request(uuid) from public, anon;
grant execute on function public.book_request(uuid)    to authenticated;
grant execute on function public.release_request(uuid) to authenticated;

-- verify C — expect exactly two rows; prosecdef = t; proconfig = {"search_path=\"\""} (one element,
-- text search_path="", because Postgres quotes the empty string); auth_exec = t; anon_exec = f
select p.proname, p.prosecdef, p.proconfig,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
       has_function_privilege('anon', p.oid, 'execute')          as anon_exec
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('book_request','release_request') order by p.proname;

-- ============================================================================
-- D: realtime
-- WARNING: never run the docs' `drop publication ... create publication supabase_realtime`
-- snippet — it wipes every other table's replication.
-- ============================================================================

alter publication supabase_realtime add table public.relocation_requests;
alter table public.relocation_requests replica identity full;

-- verify D — expect at least one row, one of them exactly: supabase_realtime | public | relocation_requests
select pubname, schemaname, tablename from pg_publication_tables where pubname='supabase_realtime';
