-- RADIUM V33: role hardening, Anyo group references, competition-status indexes,
-- and permanent scoreboard logo assets.
-- Run against an existing V32 RADIUM database.

alter table public.anyo_entries add column if not exists group_reference text;
create index if not exists idx_anyo_entries_group_reference on public.anyo_entries(tournament_id, category_id, group_reference);
create unique index if not exists uq_anyo_entries_active_group_reference
  on public.anyo_entries(tournament_id, category_id, lower(group_reference))
  where status <> 'deleted' and group_reference is not null and btrim(group_reference) <> '';

create index if not exists idx_category_registrations_player on public.category_registrations(tournament_id, player_id);
create index if not exists idx_category_registrations_team on public.category_registrations(tournament_id, team_id);
create index if not exists idx_category_registrations_category on public.category_registrations(tournament_id, category_id);

drop policy if exists players_admin on public.players;
create policy players_admin on public.players for all to authenticated
  using (has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']))
  with check (has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));

drop policy if exists teams_admin on public.teams;
create policy teams_admin on public.teams for all to authenticated
  using (has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']))
  with check (has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));

drop policy if exists categories_admin on public.categories;
create policy categories_admin on public.categories for all to authenticated
  using (has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']))
  with check (has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));

create table if not exists public.scoreboard_logos (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  slot smallint not null check(slot between 1 and 4),
  storage_path text not null,
  file_name text,
  mime_type text,
  width integer,
  height integer,
  display_mode text not null default 'contain' check(display_mode in ('contain','original')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tournament_id,slot)
);
alter table public.scoreboard_logos enable row level security;
drop policy if exists scoreboard_logos_read on public.scoreboard_logos;
create policy scoreboard_logos_read on public.scoreboard_logos for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists scoreboard_logos_write on public.scoreboard_logos;
create policy scoreboard_logos_write on public.scoreboard_logos for all to authenticated
  using(has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']))
  with check(has_tournament_role(tournament_id, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));
revoke all on table public.scoreboard_logos from anon;
grant select,insert,update,delete on table public.scoreboard_logos to authenticated;

insert into storage.buckets (id,name,public)
values ('radium-scoreboard-logos','radium-scoreboard-logos',true)
on conflict (id) do update set public=true;

drop policy if exists radium_logo_read on storage.objects;
create policy radium_logo_read on storage.objects for select to authenticated
  using(bucket_id='radium-scoreboard-logos' and is_tournament_member((split_part(name,'/',1))::uuid));
drop policy if exists radium_logo_insert on storage.objects;
create policy radium_logo_insert on storage.objects for insert to authenticated
  with check(bucket_id='radium-scoreboard-logos' and has_tournament_role((split_part(name,'/',1))::uuid, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));
drop policy if exists radium_logo_update on storage.objects;
create policy radium_logo_update on storage.objects for update to authenticated
  using(bucket_id='radium-scoreboard-logos' and has_tournament_role((split_part(name,'/',1))::uuid, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']))
  with check(bucket_id='radium-scoreboard-logos' and has_tournament_role((split_part(name,'/',1))::uuid, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));
drop policy if exists radium_logo_delete on storage.objects;
create policy radium_logo_delete on storage.objects for delete to authenticated
  using(bucket_id='radium-scoreboard-logos' and has_tournament_role((split_part(name,'/',1))::uuid, ARRAY['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));

-- Secure scoreboard writes and advance the normalized bracket for Table Officials.
-- The live V33 migration contains the full CREATE OR REPLACE definition.

create or replace function public.radium_save_match(tid uuid, incoming jsonb)
returns public.matches
language plpgsql
security definer
set search_path = public
as $$
declare
  result_row public.matches;
  caller_role text;
  caller uuid := auth.uid();
  match_id uuid;
  next_id uuid;
  next_slot text;
  next_player uuid;
  current_court uuid;
  decision_status text;
  loser_id uuid;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select coalesce(p.role,'') into caller_role from public.profiles p where p.id=caller;
  if not public.has_tournament_role(tid, array['admin','ADMIN','official','OFFICIAL','table_official','TABLE_OFFICIAL']) then raise exception 'Tournament match write permission denied'; end if;
  match_id := nullif(incoming->>'id','')::uuid;
  if match_id is null then raise exception 'Tournament match was not found'; end if;
  select m.court_id into current_court from public.matches m where m.id=match_id and m.tournament_id=tid;
  if current_court is null and not exists(select 1 from public.matches where id=match_id and tournament_id=tid) then raise exception 'Tournament match was not found'; end if;
  if upper(caller_role) in ('TABLE_OFFICIAL','OFFICIAL') and not exists(select 1 from public.staff_court_assignments s where s.tournament_id=tid and s.user_id=caller and s.court_id=current_court and s.active=true) then raise exception 'This staff account is not assigned to the match court'; end if;
  if upper(coalesce(incoming->>'status',''))='COMPLETED' then
    if nullif(incoming->>'winner_player_id','')::uuid is null then raise exception 'Completed matches require a winner'; end if;
    if not exists(select 1 from public.matches m where m.id=match_id and m.tournament_id=tid and nullif(incoming->>'winner_player_id','')::uuid in (m.red_player_id,m.blue_player_id)) then raise exception 'Winner does not belong to the current match'; end if;
  end if;
  update public.matches set
    category_id=coalesce(nullif(incoming->>'category_id','')::uuid,category_id),
    court_id=case when incoming ? 'court_id' then nullif(incoming->>'court_id','')::uuid else court_id end,
    round=coalesce(nullif(incoming->>'round','')::integer,round),
    match_number=coalesce(nullif(incoming->>'match_number','')::integer,match_number),
    bracket_position=case when incoming ? 'bracket_position' then nullif(incoming->>'bracket_position','')::integer else bracket_position end,
    blue_player_id=case when incoming ? 'blue_player_id' then nullif(incoming->>'blue_player_id','')::uuid else blue_player_id end,
    red_player_id=case when incoming ? 'red_player_id' then nullif(incoming->>'red_player_id','')::uuid else red_player_id end,
    blue_score=coalesce(nullif(incoming->>'blue_score','')::numeric,blue_score),
    red_score=coalesce(nullif(incoming->>'red_score','')::numeric,red_score),
    winner_player_id=case when incoming ? 'winner_player_id' then nullif(incoming->>'winner_player_id','')::uuid else winner_player_id end,
    status=coalesce(nullif(incoming->>'status',''),status),
    scheduled_at=case when incoming ? 'scheduled_at' then nullif(incoming->>'scheduled_at','')::timestamptz else scheduled_at end,
    started_at=case when incoming ? 'started_at' then nullif(incoming->>'started_at','')::timestamptz else started_at end,
    completed_at=case when incoming ? 'completed_at' then nullif(incoming->>'completed_at','')::timestamptz else completed_at end,
    metadata=case when incoming ? 'metadata' then coalesce(incoming->'metadata','{}'::jsonb) else metadata end,
    updated_at=now()
  where id=match_id and tournament_id=tid returning * into result_row;
  decision_status := upper(nullif(incoming->>'decision_status',''));
  loser_id := nullif(incoming->>'loser_player_id','')::uuid;
  if decision_status in ('DQ','NO_SHOW','WITHDRAWN') and loser_id is not null then
    if loser_id not in (result_row.red_player_id,result_row.blue_player_id) then raise exception 'Decision target is not a player in the current match'; end if;
    update public.category_registrations set status=decision_status,updated_at=now() where tournament_id=tid and category_id=result_row.category_id and player_id=loser_id;
  end if;
  if result_row.status='COMPLETED' and result_row.winner_player_id is not null then
    next_id := nullif(coalesce(incoming->>'nextMatchId',incoming->'metadata'->>'nextMatchId',result_row.metadata->>'nextMatchId'),'')::uuid;
    next_slot := lower(coalesce(incoming->>'nextSlot',incoming->'metadata'->>'nextSlot',result_row.metadata->>'nextSlot',''));
    if next_id is not null and next_slot in ('red','blue') then
      select case when next_slot='red' then red_player_id else blue_player_id end into next_player from public.matches where id=next_id and tournament_id=tid;
      if next_player is not null and next_player<>result_row.winner_player_id then raise exception 'The next bracket slot is already occupied by another player'; end if;
      if next_slot='red' then update public.matches set red_player_id=result_row.winner_player_id,status=case when blue_player_id is not null then 'READY' else 'PENDING' end,updated_at=now() where id=next_id and tournament_id=tid;
      else update public.matches set blue_player_id=result_row.winner_player_id,status=case when red_player_id is not null then 'READY' else 'PENDING' end,updated_at=now() where id=next_id and tournament_id=tid; end if;
    end if;
  end if;
  insert into public.audit_logs(tournament_id,user_id,role,action,entity_type,entity_id,new_value) values(tid,caller,caller_role,'SAVE_MATCH','match',result_row.id,to_jsonb(result_row));
  return result_row;
end;
$$;
revoke execute on function public.radium_save_match(uuid,jsonb) from public;
grant execute on function public.radium_save_match(uuid,jsonb) to authenticated;
