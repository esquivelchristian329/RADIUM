-- RADIUM V34: TM tournament creation + billing/logo support
-- Scope: Tournament Manager permissions for creating a tournament when no
-- unfinished tournament exists, billing type changes, and safe multi-logo flow.
-- Supabase remains authoritative. No existing tournament data is modified.

-- There must be at most one unfinished tournament (DRAFT or ACTIVE) at a time.
-- This also closes the race where two devices create tournaments concurrently.
create unique index if not exists tournaments_one_unfinished_idx
on public.tournaments ((1))
where status in ('draft','active');

create or replace function public.radium_start_tournament()
returns public.tournaments
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  uid uuid := auth.uid();
  profile_role text;
  new_row public.tournaments;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  select upper(coalesce(p.role,'')) into profile_role
  from public.profiles p
  where p.id = uid;

  if profile_role not in ('ADMIN','TOURNAMENT_MANAGER') then
    raise exception 'Admin or Tournament Manager account required';
  end if;

  if exists(select 1 from public.tournaments where status in ('draft','active')) then
    raise exception 'An unfinished tournament already exists. Complete or archive it before starting a new tournament.';
  end if;

  insert into public.tournaments (
    name, venue, event_date, organizer, status,
    official_pin_hash, billing_mode, currency, settings
  ) values (
    'Untitled Tournament', null, current_date, null, 'draft',
    null, 'PAID', 'PHP',
    jsonb_build_object(
      'version', 14,
      'setup', jsonb_build_object(
        'name','Untitled Tournament',
        'date',current_date,
        'venue','',
        'organizer','',
        'courts',2,
        'duration',120,
        'type','single',
        'competitionProgram','GENERAL',
        'gold',5,
        'silver',3,
        'bronze',1,
        'billingMode','PAID',
        'currency','PHP',
        'scoreboardLogos',jsonb_build_array('','','','')
      ),
      'activeCategory',null,
      'locked',false,
      '_cloud',jsonb_build_object('version',4)
    )
  )
  returning * into new_row;

  insert into public.tournament_users (tournament_id, user_id, role)
  values (new_row.id, uid, profile_role)
  on conflict (tournament_id,user_id) do update set role=excluded.role;

  return new_row;
exception
  when unique_violation then
    raise exception 'An unfinished tournament already exists. Complete or archive it before starting a new tournament.';
end;
$$;

revoke execute on function public.radium_start_tournament() from public;
grant execute on function public.radium_start_tournament() to authenticated;
