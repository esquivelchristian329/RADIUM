-- RADIUM V34 — Admin/Tournament Manager Supabase save + RLS role normalization
-- Apply after the existing V34 migrations on an existing Supabase project.
-- Supabase remains the authoritative data source.
-- This migration does not alter tournament data.

create or replace function public.has_tournament_role(tid uuid, roles text[])
returns boolean
language sql
security definer
stable
set search_path=public
as $$
  select
    exists (
      select 1 from public.profiles p
      where p.id=auth.uid()
        and upper(trim(coalesce(p.role,'')))='ADMIN'
    )
    or exists (
      select 1 from public.tournament_users tu
      where tu.tournament_id=tid
        and tu.user_id=auth.uid()
        and upper(trim(coalesce(tu.role,''))) = any (
          select upper(trim(r)) from unnest(coalesce(roles,array[]::text[])) as r
        )
    )
    or exists (
      select 1 from public.tournament_users tu
      where tu.tournament_id=tid
        and tu.user_id=auth.uid()
        and upper(trim(coalesce(tu.role,'')))='TOURNAMENT_MANAGER'
        and exists (
          select 1 from unnest(coalesce(roles,array[]::text[])) as r
          where upper(trim(r))='ADMIN'
        )
    );
$$;

revoke execute on function public.has_tournament_role(uuid,text[]) from public;
grant execute on function public.has_tournament_role(uuid,text[]) to authenticated;

-- Keep the protected tournament save RPC explicitly available to Admin/TM.
create or replace function public.radium_save_tournament(tid uuid, incoming jsonb)
returns public.tournaments
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  old_row public.tournaments;
  new_settings jsonb;
  result_row public.tournaments;
  caller_role text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select upper(trim(coalesce(p.role,''))) into caller_role
  from public.profiles p
  where p.id=auth.uid();

  if not public.has_tournament_role(tid,array['ADMIN','TOURNAMENT_MANAGER']) then
    raise exception 'Tournament Manager or Admin permission required';
  end if;

  select * into old_row from public.tournaments where id=tid for update;
  if not found then
    raise exception 'Tournament % not found',tid;
  end if;

  new_settings := public.radium_jsonb_merge(
    coalesce(old_row.settings,'{}'::jsonb),
    coalesce(incoming,'{}'::jsonb)
  );
  new_settings := jsonb_set(new_settings,'{_cloud,serverMergedAt}',to_jsonb(clock_timestamp()),true);
  new_settings := jsonb_set(new_settings,'{_cloud,serverRevision}',to_jsonb(extract(epoch from clock_timestamp())::bigint),true);

  update public.tournaments
  set
    name=coalesce(new_settings->'setup'->>'name',old_row.name),
    venue=nullif(new_settings->'setup'->>'venue',''),
    event_date=case
      when nullif(new_settings->'setup'->>'date','') is null then old_row.event_date
      else (new_settings->'setup'->>'date')::date
    end,
    organizer=nullif(new_settings->'setup'->>'organizer',''),
    official_pin_hash=coalesce(new_settings->'_cloud'->>'officialPinHash',old_row.official_pin_hash),
    billing_mode=coalesce(new_settings->'_cloud'->>'billingMode',old_row.billing_mode),
    currency=coalesce(new_settings->'_cloud'->>'currency',old_row.currency),
    settings=new_settings
  where id=tid
  returning * into result_row;

  return result_row;
end;
$$;

revoke execute on function public.radium_save_tournament(uuid,jsonb) from public;
grant execute on function public.radium_save_tournament(uuid,jsonb) to authenticated;
