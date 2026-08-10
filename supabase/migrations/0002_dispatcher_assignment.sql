-- 0002_dispatcher_assignment.sql
-- Dispatcher-side assignment, added after the T+185 freeze at explicit request.
--
-- Why this is not a client UPDATE. The dispatcher DOES hold an UPDATE policy on their own
-- rows, so `update ... set driver_id = ..., status = 'booked'` would pass RLS. It is still
-- wrong: it puts three interdependent columns (driver_id, status, booked_at) under client
-- control, where the CHECK constraints become the only thing standing between a typo and a
-- row that is 'booked' with no driver. Both transitions below are single guarded UPDATEs in
-- SECURITY DEFINER functions, exactly like book_request — the client names an intent, never
-- a state.
--
-- `release_request` already exists from 0001 and needs no change: it is the driver's own
-- cancel path, and it was written before it had a button.

create function public.assign_driver(p_request_id uuid, p_driver_id uuid)
returns public.relocation_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_row public.relocation_requests;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;

  -- The same rule book_request enforces from the other side: a dispatcher cannot be the
  -- driver on their own job. Raised distinctly here, because unlike a lost race this one
  -- is a mistake the user can correct.
  if p_driver_id = v_uid then
    raise exception 'You cannot assign yourself to your own request' using errcode = 'P0001';
  end if;

  update public.relocation_requests r
     set driver_id = p_driver_id, status = 'booked', booked_at = now()
   where r.id = p_request_id
     and r.dispatcher_id = v_uid      -- only your own board
     and r.status = 'open'            -- never steal a gig a driver already took
     and r.driver_id is null
  returning r.* into v_row;

  if not found then
    raise exception 'This request is no longer open' using errcode = 'P0001';
  end if;
  return v_row;
end; $$;

create function public.unassign_driver(p_request_id uuid)
returns public.relocation_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_row public.relocation_requests;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;

  update public.relocation_requests r
     set driver_id = null, status = 'open', booked_at = null
   where r.id = p_request_id
     and r.dispatcher_id = v_uid
     and r.status = 'booked'
     and r.driver_id is not null
  returning r.* into v_row;

  if not found then
    raise exception 'This request has no driver to remove' using errcode = 'P0001';
  end if;
  return v_row;
end; $$;

revoke all on function public.assign_driver(uuid, uuid) from public, anon;
revoke all on function public.unassign_driver(uuid)     from public, anon;
grant execute on function public.assign_driver(uuid, uuid) to authenticated;
grant execute on function public.unassign_driver(uuid)     to authenticated;

-- verify — expect four rows; prosecdef = t, proconfig = {"search_path=\"\""},
-- auth_exec = t, anon_exec = f on every one
select p.proname, p.prosecdef, p.proconfig,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
       has_function_privilege('anon', p.oid, 'execute')          as anon_exec
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('book_request','release_request','assign_driver','unassign_driver')
order by p.proname;
