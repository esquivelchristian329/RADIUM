-- RADIUM V25 Anyo entry model
-- Individual, Synchronized Anyo (2-3), and Mixed Anyo (1 male + 1 female)

DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
  WHERE conrelid='public.player_anyo_events'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%division%';
  IF c IS NOT NULL THEN EXECUTE format('alter table public.player_anyo_events drop constraint %I',c); END IF;
END $$;
alter table public.player_anyo_events add constraint player_anyo_events_division_check check (division in ('Individual','Synchronized'));

create table if not exists public.anyo_entries (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  entry_type text not null check (entry_type in ('Individual','Synchronized','Mixed')),
  entry_number text,
  style text not null check (style in ('Traditional','Non-Traditional')),
  weapon text not null check (weapon in ('Single Weapon','Double Weapon','Espada y Daga')),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.anyo_entry_members (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  entry_id uuid not null references public.anyo_entries(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  member_position integer not null check (member_position between 1 and 3),
  created_at timestamptz not null default now(),
  unique(entry_id, member_position),
  unique(entry_id, player_id)
);

create index if not exists idx_anyo_entries_tournament on public.anyo_entries(tournament_id);
create index if not exists idx_anyo_entries_category on public.anyo_entries(category_id);
create index if not exists idx_anyo_entry_members_tournament on public.anyo_entry_members(tournament_id);
create index if not exists idx_anyo_entry_members_entry on public.anyo_entry_members(entry_id);
create index if not exists idx_anyo_entry_members_player on public.anyo_entry_members(player_id);

alter table public.anyo_entries enable row level security;
alter table public.anyo_entry_members enable row level security;

drop policy if exists anyo_entries_read on public.anyo_entries;
create policy anyo_entries_read on public.anyo_entries for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists anyo_entries_admin on public.anyo_entries;
create policy anyo_entries_admin on public.anyo_entries for all to authenticated using (has_tournament_role(tournament_id,array['admin'])) with check (has_tournament_role(tournament_id,array['admin']));

drop policy if exists anyo_entry_members_read on public.anyo_entry_members;
create policy anyo_entry_members_read on public.anyo_entry_members for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists anyo_entry_members_admin on public.anyo_entry_members;
create policy anyo_entry_members_admin on public.anyo_entry_members for all to authenticated using (has_tournament_role(tournament_id,array['admin'])) with check (has_tournament_role(tournament_id,array['admin']));

drop trigger if exists anyo_entries_updated_at on public.anyo_entries;
create trigger anyo_entries_updated_at before update on public.anyo_entries for each row execute function radium_updated_at();

alter table public.anyo_performances add column if not exists entry_id uuid references public.anyo_entries(id) on delete cascade;
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
  WHERE conrelid='public.anyo_performances'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%player_id%team_id%';
  IF c IS NOT NULL THEN EXECUTE format('alter table public.anyo_performances drop constraint %I',c); END IF;
END $$;
alter table public.anyo_performances add constraint anyo_performances_owner_check check (
  (entry_id is not null and player_id is null and team_id is null)
  or (entry_id is null and ((player_id is not null and team_id is null) or (player_id is null and team_id is not null)))
);
create unique index if not exists uq_anyo_performer_entry on public.anyo_performances(category_id,entry_id) where entry_id is not null;
create index if not exists idx_anyo_performances_entry on public.anyo_performances(entry_id);

alter table public.tournament_medals add column if not exists entry_id uuid references public.anyo_entries(id) on delete cascade;
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
  WHERE conrelid='public.tournament_medals'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%player_id%team_id%';
  IF c IS NOT NULL THEN EXECUTE format('alter table public.tournament_medals drop constraint %I',c); END IF;
END $$;
alter table public.tournament_medals add constraint tournament_medals_owner_check check (
  (entry_id is not null and player_id is null and team_id is null)
  or (entry_id is null and ((player_id is not null and team_id is null) or (player_id is null and team_id is not null)))
);
create index if not exists idx_tournament_medals_entry on public.tournament_medals(entry_id);
create unique index if not exists uq_tournament_medal_entry on public.tournament_medals(category_id,entry_id,medal) where entry_id is not null;

-- Migrate legacy category label/value if one exists.
update public.categories set division='Synchronized' where event_type='Anyo' and division='Team';
revoke all on table public.anyo_entries from anon;
revoke all on table public.anyo_entry_members from anon;
grant select, insert, update, delete on table public.anyo_entries to authenticated;
grant select, insert, update, delete on table public.anyo_entry_members to authenticated;
