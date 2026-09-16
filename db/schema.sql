create extension if not exists pgcrypto;

create table if not exists tournaments (id uuid primary key default gen_random_uuid(), name text not null, venue text, event_date date, organizer text, status text not null default 'draft' check(status in ('draft','active','completed','archived')), official_pin_hash text, settings jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text, role text not null default 'official' check(role in ('admin','official','table_official','display')), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists tournament_users (tournament_id uuid references tournaments(id) on delete cascade, user_id uuid references profiles(id) on delete cascade, role text not null default 'official' check(role in ('admin','official','table_official','display')), created_at timestamptz not null default now(), primary key(tournament_id,user_id));
create table if not exists teams (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, name text not null, abbreviation text, logo_url text, coach text, manager text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists players (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, team_id uuid references teams(id) on delete set null, first_name text not null, middle_name text, last_name text not null, nickname text, gender text, birthdate date, age integer, weight numeric(6,2), school text, player_number text, seed integer, coach text, photo_url text, events jsonb not null default '{}', status text not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists categories (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, name text not null, event_type text not null check(event_type in ('Combative','Anyo','Livestick')), gender text, event_number text, judges integer not null default 5, preset text, weight_required boolean not null default false, bracket_by text, bracket jsonb not null default '{}', age_min integer, age_max integer, weight_min numeric(6,2), weight_max numeric(6,2), division text, style text, weapon text, scoring_type text, rules jsonb not null default '{}', status text not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists category_players (category_id uuid references categories(id) on delete cascade, player_id uuid references players(id) on delete cascade, seed integer, status text not null default 'active', created_at timestamptz not null default now(), primary key(category_id,player_id));
create table if not exists courts (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, name text not null, court_number integer not null, active boolean not null default true, unique(tournament_id,court_number));
create table if not exists matches (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, category_id uuid not null references categories(id) on delete cascade, court_id uuid references courts(id) on delete set null, round integer not null default 1, match_number integer not null, bracket_position integer, blue_player_id uuid references players(id) on delete set null, red_player_id uuid references players(id) on delete set null, blue_score numeric(8,3) not null default 0, red_score numeric(8,3) not null default 0, winner_player_id uuid references players(id) on delete set null, status text not null default 'PENDING' check(status in ('PENDING','READY','CALLED','LIVE','COMPLETED','CANCELLED','BYE')), scheduled_at timestamptz, started_at timestamptz, completed_at timestamptz, metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(category_id,round,match_number));
create table if not exists match_results (id uuid primary key default gen_random_uuid(), match_id uuid not null unique references matches(id) on delete cascade, blue_score numeric(8,3) not null default 0, red_score numeric(8,3) not null default 0, blue_round_wins integer not null default 0, red_round_wins integer not null default 0, winner_player_id uuid references players(id) on delete set null, blue_fouls integer not null default 0, red_fouls integer not null default 0, blue_disarms integer not null default 0, red_disarms integer not null default 0, submitted_by uuid references profiles(id) on delete set null, created_at timestamptz not null default now());
create table if not exists anyo_judges (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, name text not null, judge_number integer not null, active boolean not null default true, unique(tournament_id,judge_number));
create table if not exists anyo_judge_scores (id uuid primary key default gen_random_uuid(), match_id uuid not null references matches(id) on delete cascade, player_id uuid not null references players(id) on delete cascade, judge_id uuid not null references anyo_judges(id) on delete cascade, score numeric(4,2) not null check(score between 7.50 and 10.00), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(match_id,player_id,judge_id));
create table if not exists anyo_deductions (id uuid primary key default gen_random_uuid(), match_id uuid not null references matches(id) on delete cascade, player_id uuid not null references players(id) on delete cascade, violation_type text not null check(violation_type in ('TIME','DISARM','OUT_OF_MAT','OTHER')), quantity integer not null default 1 check(quantity>0), deduction_amount numeric(6,3) not null check(deduction_amount>=0), recorded_by uuid references profiles(id) on delete set null, created_at timestamptz not null default now());

create table if not exists weigh_ins (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  weight numeric(6,2),
  verified boolean not null default false,
  verified_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(category_id,player_id)
);

create table if not exists anyo_performances (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  player_id uuid references players(id) on delete cascade,
  team_id uuid references teams(id) on delete cascade,
  performer_index integer not null default 0,
  judge_count integer not null default 5,
  raw_total numeric(8,3) not null default 0,
  kept_total numeric(8,3) not null default 0,
  average numeric(8,3) not null default 0,
  judge_average numeric(8,3) not null default 0,
  final_score numeric(8,3) not null default 0,
  total_deduction numeric(8,3) not null default 0,
  deduction_rates jsonb not null default '{}',
  dropped_scores jsonb not null default '[]',
  elapsed_ms bigint not null default 0,
  elapsed_time text,
  finished boolean not null default true,
  started_at timestamptz,
  finished_at timestamptz,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((player_id is not null and team_id is null) or (player_id is null and team_id is not null))
);
create unique index if not exists uq_anyo_performer_player on anyo_performances(category_id,player_id) where player_id is not null;
create unique index if not exists uq_anyo_performer_team on anyo_performances(category_id,team_id) where team_id is not null;

create table if not exists anyo_performance_scores (
  id uuid primary key default gen_random_uuid(),
  performance_id uuid not null references anyo_performances(id) on delete cascade,
  judge_id uuid not null references anyo_judges(id) on delete cascade,
  score numeric(4,2) not null check(score between 7.50 and 10.00),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(performance_id,judge_id)
);

create table if not exists anyo_performance_deductions (
  id uuid primary key default gen_random_uuid(),
  performance_id uuid not null references anyo_performances(id) on delete cascade,
  violation_type text not null check(violation_type in ('TIME','DISARM','OUT_OF_MAT','OTHER')),
  quantity integer not null default 1 check(quantity>0),
  deduction_amount numeric(6,3) not null check(deduction_amount>=0),
  recorded_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists tournament_medals (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  player_id uuid references players(id) on delete cascade,
  team_id uuid references teams(id) on delete cascade,
  medal text not null check(medal in ('gold','silver','bronze')),
  source text not null default 'combat',
  score numeric(8,3),
  awarded_at timestamptz not null default now(),
  check ((player_id is not null and team_id is null) or (player_id is null and team_id is not null))
);
create unique index if not exists uq_tournament_medal_player on tournament_medals(category_id,player_id,medal) where player_id is not null;
create unique index if not exists uq_tournament_medal_team on tournament_medals(category_id,team_id,medal) where team_id is not null;


-- Idempotent upgrades for existing RADIUM databases.
alter table players add column if not exists nickname text;
alter table players add column if not exists seed integer;
alter table players add column if not exists coach text;
alter table players add column if not exists events jsonb not null default '{}';
alter table categories add column if not exists event_number text;
alter table categories add column if not exists judges integer not null default 5;
alter table categories add column if not exists preset text;
alter table categories add column if not exists weight_required boolean not null default false;
alter table categories add column if not exists bracket_by text;
alter table categories add column if not exists bracket jsonb not null default '{}';

create table if not exists audit_logs (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, user_id uuid references profiles(id) on delete set null, role text, action text not null, entity_type text, entity_id uuid, old_value jsonb, new_value jsonb, created_at timestamptz not null default now());
create index if not exists idx_players_tournament on players(tournament_id); create index if not exists idx_categories_tournament on categories(tournament_id); create index if not exists idx_weighins_tournament on weigh_ins(tournament_id); create index if not exists idx_anyo_perf_tournament on anyo_performances(tournament_id); create index if not exists idx_anyo_scores_perf on anyo_performance_scores(performance_id); create index if not exists idx_anyo_deductions_perf on anyo_performance_deductions(performance_id); create index if not exists idx_medals_tournament on tournament_medals(tournament_id); create index if not exists idx_matches_queue on matches(tournament_id,status,court_id,scheduled_at); create index if not exists idx_audit_tournament on audit_logs(tournament_id,created_at desc);

create or replace function radium_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;

drop trigger if exists tournaments_updated_at on tournaments; create trigger tournaments_updated_at before update on tournaments for each row execute function radium_updated_at();
drop trigger if exists profiles_updated_at on profiles; create trigger profiles_updated_at before update on profiles for each row execute function radium_updated_at();
drop trigger if exists teams_updated_at on teams; create trigger teams_updated_at before update on teams for each row execute function radium_updated_at();
drop trigger if exists players_updated_at on players; create trigger players_updated_at before update on players for each row execute function radium_updated_at();
drop trigger if exists categories_updated_at on categories; create trigger categories_updated_at before update on categories for each row execute function radium_updated_at();
drop trigger if exists matches_updated_at on matches; create trigger matches_updated_at before update on matches for each row execute function radium_updated_at();
drop trigger if exists anyo_scores_updated_at on anyo_judge_scores; create trigger anyo_scores_updated_at before update on anyo_judge_scores for each row execute function radium_updated_at();
drop trigger if exists weigh_ins_updated_at on weigh_ins; create trigger weigh_ins_updated_at before update on weigh_ins for each row execute function radium_updated_at();
drop trigger if exists anyo_perf_updated_at on anyo_performances; create trigger anyo_perf_updated_at before update on anyo_performances for each row execute function radium_updated_at();
drop trigger if exists anyo_perf_scores_updated_at on anyo_performance_scores; create trigger anyo_perf_scores_updated_at before update on anyo_performance_scores for each row execute function radium_updated_at();

create or replace function is_tournament_member(tid uuid) returns boolean language sql security definer stable set search_path=public as $$ select exists(select 1 from tournament_users where tournament_id=tid and user_id=auth.uid()) $$;
create or replace function has_tournament_role(tid uuid, roles text[])
returns boolean language sql security definer stable set search_path=public as $$
  select
    exists (
      select 1 from profiles p
      where p.id=auth.uid()
        and upper(trim(coalesce(p.role,'')))='ADMIN'
    )
    or exists (
      select 1 from tournament_users tu
      where tu.tournament_id=tid
        and tu.user_id=auth.uid()
        and upper(trim(coalesce(tu.role,''))) = any (
          select upper(trim(r)) from unnest(coalesce(roles,array[]::text[])) as r
        )
    )
    or exists (
      select 1 from tournament_users tu
      where tu.tournament_id=tid
        and tu.user_id=auth.uid()
        and upper(trim(coalesce(tu.role,'')))='TOURNAMENT_MANAGER'
        and exists (
          select 1 from unnest(coalesce(roles,array[]::text[])) as r
          where upper(trim(r))='ADMIN'
        )
    )
$$;
grant execute on function is_tournament_member(uuid) to authenticated; grant execute on function has_tournament_role(uuid,text[]) to authenticated;

alter table tournaments enable row level security; alter table profiles enable row level security; alter table tournament_users enable row level security; alter table teams enable row level security; alter table players enable row level security; alter table categories enable row level security; alter table category_players enable row level security; alter table courts enable row level security; alter table matches enable row level security; alter table match_results enable row level security; alter table anyo_judges enable row level security; alter table anyo_judge_scores enable row level security; alter table anyo_deductions enable row level security; alter table weigh_ins enable row level security; alter table anyo_performances enable row level security; alter table anyo_performance_scores enable row level security; alter table anyo_performance_deductions enable row level security; alter table tournament_medals enable row level security; alter table audit_logs enable row level security;

-- Core policies. Add/adjust policies as needed for your deployment.
drop policy if exists tournaments_member_select on tournaments; create policy tournaments_member_select on tournaments for select to authenticated using(has_tournament_role(id,array['admin']) or is_tournament_member(id));
drop policy if exists tournaments_admin_all on tournaments; create policy tournaments_admin_all on tournaments for all to authenticated using(has_tournament_role(id,array['admin'])) with check(has_tournament_role(id,array['admin']) or exists(select 1 from profiles p where p.id=auth.uid() and p.role='admin'));
drop policy if exists profiles_self on profiles; create policy profiles_self on profiles for all to authenticated using(id=auth.uid()) with check(id=auth.uid());
drop policy if exists tu_member_select on tournament_users; create policy tu_member_select on tournament_users for select to authenticated using(user_id=auth.uid() or has_tournament_role(tournament_id,array['admin']));
drop policy if exists tu_admin_all on tournament_users; create policy tu_admin_all on tournament_users for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));

-- Member read policies
create policy teams_read on teams for select to authenticated using(is_tournament_member(tournament_id));
create policy players_read on players for select to authenticated using(is_tournament_member(tournament_id));
create policy categories_read on categories for select to authenticated using(is_tournament_member(tournament_id));
create policy courts_read on courts for select to authenticated using(is_tournament_member(tournament_id));
create policy matches_read on matches for select to authenticated using(is_tournament_member(tournament_id));
create policy audit_read on audit_logs for select to authenticated using(is_tournament_member(tournament_id));
create policy audit_insert on audit_logs for insert to authenticated with check(is_tournament_member(tournament_id));

-- Admin CRUD
create policy teams_admin on teams for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
create policy players_admin on players for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
create policy categories_admin on categories for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
create policy courts_admin on courts for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));

drop policy if exists category_players_read on category_players; create policy category_players_read on category_players for select to authenticated using(exists(select 1 from categories c where c.id=category_id and is_tournament_member(c.tournament_id)));
drop policy if exists category_players_admin on category_players; create policy category_players_admin on category_players for all to authenticated using(exists(select 1 from categories c where c.id=category_id and has_tournament_role(c.tournament_id,array['admin']))) with check(exists(select 1 from categories c where c.id=category_id and has_tournament_role(c.tournament_id,array['admin'])));

-- Match/result write access for officials.
create policy matches_admin_insert on matches for insert to authenticated with check(has_tournament_role(tournament_id,array['admin']));
create policy matches_official_update on matches for update to authenticated using(has_tournament_role(tournament_id,array['admin','official','table_official'])) with check(has_tournament_role(tournament_id,array['admin','official','table_official']));
create policy match_results_read on match_results for select to authenticated using(exists(select 1 from matches m where m.id=match_id and is_tournament_member(m.tournament_id)));
create policy match_results_insert on match_results for insert to authenticated with check(exists(select 1 from matches m where m.id=match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official'])));

create policy anyo_judges_read on anyo_judges for select to authenticated using(is_tournament_member(tournament_id));
create policy anyo_judges_admin on anyo_judges for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
create policy anyo_scores_read on anyo_judge_scores for select to authenticated using(exists(select 1 from matches m where m.id=match_id and is_tournament_member(m.tournament_id)));
create policy anyo_scores_write on anyo_judge_scores for all to authenticated using(exists(select 1 from matches m where m.id=match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official']))) with check(exists(select 1 from matches m where m.id=match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official'])));
create policy anyo_deductions_read on anyo_deductions for select to authenticated using(exists(select 1 from matches m where m.id=match_id and is_tournament_member(m.tournament_id)));
create policy anyo_deductions_write on anyo_deductions for all to authenticated using(exists(select 1 from matches m where m.id=match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official']))) with check(exists(select 1 from matches m where m.id=match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official'])));


drop policy if exists weighins_read on weigh_ins; create policy weighins_read on weigh_ins for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists weighins_admin on weigh_ins; create policy weighins_admin on weigh_ins for all to authenticated using(has_tournament_role(tournament_id,array['admin','official','table_official'])) with check(has_tournament_role(tournament_id,array['admin','official','table_official']));
drop policy if exists anyo_perf_read on anyo_performances; create policy anyo_perf_read on anyo_performances for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists anyo_perf_write on anyo_performances; create policy anyo_perf_write on anyo_performances for all to authenticated using(has_tournament_role(tournament_id,array['admin','official','table_official'])) with check(has_tournament_role(tournament_id,array['admin','official','table_official']));
drop policy if exists anyo_perf_scores_read on anyo_performance_scores; create policy anyo_perf_scores_read on anyo_performance_scores for select to authenticated using(exists(select 1 from anyo_performances p where p.id=performance_id and is_tournament_member(p.tournament_id)));
drop policy if exists anyo_perf_scores_write on anyo_performance_scores; create policy anyo_perf_scores_write on anyo_performance_scores for all to authenticated using(exists(select 1 from anyo_performances p where p.id=performance_id and has_tournament_role(p.tournament_id,array['admin','official','table_official']))) with check(exists(select 1 from anyo_performances p where p.id=performance_id and has_tournament_role(p.tournament_id,array['admin','official','table_official'])));
drop policy if exists anyo_perf_deductions_read on anyo_performance_deductions; create policy anyo_perf_deductions_read on anyo_performance_deductions for select to authenticated using(exists(select 1 from anyo_performances p where p.id=performance_id and is_tournament_member(p.tournament_id)));
drop policy if exists anyo_perf_deductions_write on anyo_performance_deductions; create policy anyo_perf_deductions_write on anyo_performance_deductions for all to authenticated using(exists(select 1 from anyo_performances p where p.id=performance_id and has_tournament_role(p.tournament_id,array['admin','official','table_official']))) with check(exists(select 1 from anyo_performances p where p.id=performance_id and has_tournament_role(p.tournament_id,array['admin','official','table_official'])));
drop policy if exists medals_read on tournament_medals; create policy medals_read on tournament_medals for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists medals_admin on tournament_medals; create policy medals_admin on tournament_medals for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));

alter publication supabase_realtime add table anyo_performances;
alter publication supabase_realtime add table anyo_performance_scores;
alter publication supabase_realtime add table anyo_performance_deductions;
alter publication supabase_realtime add table tournament_medals;

-- Realtime for live scoreboard / LED wall.
alter publication supabase_realtime add table matches;
alter publication supabase_realtime add table match_results;
alter publication supabase_realtime add table anyo_judge_scores;
alter publication supabase_realtime add table anyo_deductions;
alter publication supabase_realtime add table audit_logs;

create or replace view live_match_queue as select m.id,m.tournament_id,m.category_id,c.name category_name,c.event_type,m.court_id,co.name court_name,m.round,m.match_number,m.status,m.scheduled_at,concat_ws(' ',bp.first_name,bp.last_name) blue_name,concat_ws(' ',rp.first_name,rp.last_name) red_name from matches m join categories c on c.id=m.category_id left join courts co on co.id=m.court_id left join players bp on bp.id=m.blue_player_id left join players rp on rp.id=m.red_player_id where m.status in ('READY','CALLED','LIVE','PENDING');

-- Security hardening: fixed search paths and never expose the RLS event-trigger helper.
alter function public.radium_updated_at() set search_path = public;
alter function public.radium_jsonb_merge(jsonb,jsonb) set search_path = public;
revoke execute on function public.rls_auto_enable() from public;
