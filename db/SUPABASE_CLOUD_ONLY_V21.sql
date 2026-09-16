-- RADIUM V21 CLOUD-ONLY DATA MODEL MIGRATION
-- Run this once against the existing Supabase database before using the V21 build.

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

create table if not exists weigh_ins (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, category_id uuid not null references categories(id) on delete cascade, player_id uuid not null references players(id) on delete cascade, weight numeric(6,2), verified boolean not null default false, verified_at timestamptz, updated_at timestamptz not null default now(), unique(category_id,player_id));
create table if not exists anyo_performances (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, category_id uuid not null references categories(id) on delete cascade, player_id uuid references players(id) on delete cascade, team_id uuid references teams(id) on delete cascade, performer_index integer not null default 0, judge_count integer not null default 5, raw_total numeric(8,3) not null default 0, kept_total numeric(8,3) not null default 0, average numeric(8,3) not null default 0, judge_average numeric(8,3) not null default 0, final_score numeric(8,3) not null default 0, total_deduction numeric(8,3) not null default 0, deduction_rates jsonb not null default '{}', dropped_scores jsonb not null default '[]', elapsed_ms bigint not null default 0, elapsed_time text, finished boolean not null default true, started_at timestamptz, finished_at timestamptz, metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check ((player_id is not null and team_id is null) or (player_id is null and team_id is not null)));
create unique index if not exists uq_anyo_performer_player on anyo_performances(category_id,player_id) where player_id is not null;
create unique index if not exists uq_anyo_performer_team on anyo_performances(category_id,team_id) where team_id is not null;
create table if not exists anyo_performance_scores (id uuid primary key default gen_random_uuid(), performance_id uuid not null references anyo_performances(id) on delete cascade, judge_id uuid not null references anyo_judges(id) on delete cascade, score numeric(4,2) not null check(score between 7.50 and 10.00), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(performance_id,judge_id));
create table if not exists anyo_performance_deductions (id uuid primary key default gen_random_uuid(), performance_id uuid not null references anyo_performances(id) on delete cascade, violation_type text not null check(violation_type in ('TIME','DISARM','OUT_OF_MAT','OTHER')), quantity integer not null default 1 check(quantity>0), deduction_amount numeric(6,3) not null check(deduction_amount>=0), recorded_by uuid references profiles(id) on delete set null, created_at timestamptz not null default now());
create table if not exists tournament_medals (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, category_id uuid not null references categories(id) on delete cascade, player_id uuid references players(id) on delete cascade, team_id uuid references teams(id) on delete cascade, medal text not null check(medal in ('gold','silver','bronze')), source text not null default 'combat', score numeric(8,3), awarded_at timestamptz not null default now(), check ((player_id is not null and team_id is null) or (player_id is null and team_id is not null)));
create unique index if not exists uq_tournament_medal_player on tournament_medals(category_id,player_id,medal) where player_id is not null;
create unique index if not exists uq_tournament_medal_team on tournament_medals(category_id,team_id,medal) where team_id is not null;

alter table weigh_ins enable row level security;
alter table anyo_performances enable row level security;
alter table anyo_performance_scores enable row level security;
alter table anyo_performance_deductions enable row level security;
alter table tournament_medals enable row level security;

drop trigger if exists weigh_ins_updated_at on weigh_ins; create trigger weigh_ins_updated_at before update on weigh_ins for each row execute function radium_updated_at();
drop trigger if exists anyo_perf_updated_at on anyo_performances; create trigger anyo_perf_updated_at before update on anyo_performances for each row execute function radium_updated_at();
drop trigger if exists anyo_perf_scores_updated_at on anyo_performance_scores; create trigger anyo_perf_scores_updated_at before update on anyo_performance_scores for each row execute function radium_updated_at();

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

create index if not exists idx_weighins_tournament on weigh_ins(tournament_id);
create index if not exists idx_anyo_perf_tournament on anyo_performances(tournament_id);
create index if not exists idx_anyo_scores_perf on anyo_performance_scores(performance_id);
create index if not exists idx_anyo_deductions_perf on anyo_performance_deductions(performance_id);
create index if not exists idx_medals_tournament on tournament_medals(tournament_id);


-- V22 normalized Anyo player registrations
create table if not exists player_anyo_events (id uuid primary key default gen_random_uuid(), tournament_id uuid not null references tournaments(id) on delete cascade, player_id uuid not null references players(id) on delete cascade, division text not null check (division in ('Individual','Team')), style text not null check (style in ('Traditional','Non-Traditional')), weapon text not null check (weapon in ('Single Weapon','Double Weapon','Espada y Daga')), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(player_id,division,style,weapon));
alter table player_anyo_events enable row level security;
drop policy if exists player_anyo_events_read on player_anyo_events; create policy player_anyo_events_read on player_anyo_events for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists player_anyo_events_admin on player_anyo_events; create policy player_anyo_events_admin on player_anyo_events for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
create index if not exists idx_player_anyo_events_tournament on player_anyo_events(tournament_id);
create index if not exists idx_player_anyo_events_player on player_anyo_events(player_id);
drop trigger if exists player_anyo_events_updated_at on player_anyo_events; create trigger player_anyo_events_updated_at before update on player_anyo_events for each row execute function radium_updated_at();

-- V25 Anyo entries: Individual, Synchronized (2-3), Mixed (1 male + 1 female)
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint WHERE conrelid='public.player_anyo_events'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%division%';
  IF c IS NOT NULL THEN EXECUTE format('alter table public.player_anyo_events drop constraint %I',c); END IF;
END $$;
alter table public.player_anyo_events add constraint player_anyo_events_division_check check (division in ('Individual','Synchronized'));
create table if not exists public.anyo_entries (id uuid primary key default gen_random_uuid(),tournament_id uuid not null references public.tournaments(id) on delete cascade,category_id uuid not null references public.categories(id) on delete cascade,entry_type text not null check (entry_type in ('Individual','Synchronized','Mixed')),entry_number text,style text not null check (style in ('Traditional','Non-Traditional')),weapon text not null check (weapon in ('Single Weapon','Double Weapon','Espada y Daga')),status text not null default 'active',created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.anyo_entry_members (id uuid primary key default gen_random_uuid(),tournament_id uuid not null references public.tournaments(id) on delete cascade,entry_id uuid not null references public.anyo_entries(id) on delete cascade,player_id uuid not null references public.players(id) on delete cascade,member_position integer not null check (member_position between 1 and 3),created_at timestamptz not null default now(),unique(entry_id,member_position),unique(entry_id,player_id));
create index if not exists idx_anyo_entries_tournament on public.anyo_entries(tournament_id);create index if not exists idx_anyo_entries_category on public.anyo_entries(category_id);create index if not exists idx_anyo_entry_members_tournament on public.anyo_entry_members(tournament_id);create index if not exists idx_anyo_entry_members_entry on public.anyo_entry_members(entry_id);create index if not exists idx_anyo_entry_members_player on public.anyo_entry_members(player_id);
alter table public.anyo_entries enable row level security;alter table public.anyo_entry_members enable row level security;
drop policy if exists anyo_entries_read on public.anyo_entries;create policy anyo_entries_read on public.anyo_entries for select to authenticated using(is_tournament_member(tournament_id));drop policy if exists anyo_entries_admin on public.anyo_entries;create policy anyo_entries_admin on public.anyo_entries for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
drop policy if exists anyo_entry_members_read on public.anyo_entry_members;create policy anyo_entry_members_read on public.anyo_entry_members for select to authenticated using(is_tournament_member(tournament_id));drop policy if exists anyo_entry_members_admin on public.anyo_entry_members;create policy anyo_entry_members_admin on public.anyo_entry_members for all to authenticated using(has_tournament_role(tournament_id,array['admin'])) with check(has_tournament_role(tournament_id,array['admin']));
drop trigger if exists anyo_entries_updated_at on public.anyo_entries;create trigger anyo_entries_updated_at before update on public.anyo_entries for each row execute function radium_updated_at();
alter table public.anyo_performances add column if not exists entry_id uuid references public.anyo_entries(id) on delete cascade;
DO $$ DECLARE c text; BEGIN SELECT conname INTO c FROM pg_constraint WHERE conrelid='public.anyo_performances'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%player_id%team_id%'; IF c IS NOT NULL THEN EXECUTE format('alter table public.anyo_performances drop constraint %I',c); END IF; END $$;
alter table public.anyo_performances add constraint anyo_performances_owner_check check ((entry_id is not null and player_id is null and team_id is null) or (entry_id is null and ((player_id is not null and team_id is null) or (player_id is null and team_id is not null))));
create unique index if not exists uq_anyo_performer_entry on public.anyo_performances(category_id,entry_id) where entry_id is not null;create index if not exists idx_anyo_performances_entry on public.anyo_performances(entry_id);
alter table public.tournament_medals add column if not exists entry_id uuid references public.anyo_entries(id) on delete cascade;
DO $$ DECLARE c text; BEGIN SELECT conname INTO c FROM pg_constraint WHERE conrelid='public.tournament_medals'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%player_id%team_id%'; IF c IS NOT NULL THEN EXECUTE format('alter table public.tournament_medals drop constraint %I',c); END IF; END $$;
alter table public.tournament_medals add constraint tournament_medals_owner_check check ((entry_id is not null and player_id is null and team_id is null) or (entry_id is null and ((player_id is not null and team_id is null) or (player_id is null and team_id is not null))));
create index if not exists idx_tournament_medals_entry on public.tournament_medals(entry_id);create unique index if not exists uq_tournament_medal_entry on public.tournament_medals(category_id,entry_id,medal) where entry_id is not null;
update public.categories set division='Synchronized' where event_type='Anyo' and division='Team';
revoke all on table public.anyo_entries from anon;revoke all on table public.anyo_entry_members from anon;grant select,insert,update,delete on table public.anyo_entries to authenticated;grant select,insert,update,delete on table public.anyo_entry_members to authenticated;

-- ============================================================
-- RADIUM V26 STAFF / REGISTRATION / ACCOUNTING ADDITIONS
-- ============================================================
-- RADIUM V26: staff roles, court assignments, registrations, payments, attendance
-- Apply to the V25 schema. All primary IDs are Supabase-generated UUIDs.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles alter column role set default 'ADMIN';
update public.profiles set role=upper(role);
alter table public.profiles add constraint profiles_role_check check(role in ('ADMIN','TOURNAMENT_MANAGER','ACCOUNTANT','TABLE_OFFICIAL'));

alter table public.tournament_users drop constraint if exists tournament_users_role_check;
update public.tournament_users set role=upper(role);
alter table public.tournament_users add constraint tournament_users_role_check check(role in ('ADMIN','TOURNAMENT_MANAGER','ACCOUNTANT','TABLE_OFFICIAL'));

create table if not exists public.staff_court_assignments (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, court_id uuid not null references public.courts(id) on delete cascade,
 active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tournament_id,user_id,court_id)
);
create index if not exists idx_staff_court_tournament on public.staff_court_assignments(tournament_id);
create index if not exists idx_staff_court_user on public.staff_court_assignments(user_id);
create index if not exists idx_staff_court_court on public.staff_court_assignments(court_id);

create table if not exists public.category_registrations (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 team_id uuid references public.teams(id) on delete set null, player_id uuid references public.players(id) on delete set null,
 category_id uuid not null references public.categories(id) on delete cascade, anyo_entry_id uuid references public.anyo_entries(id) on delete set null,
 status text not null default 'ACTIVE' check(status in ('ACTIVE','WITHDRAWN','NO_SHOW','DQ')),
 fee_amount numeric(12,2) not null default 0 check(fee_amount>=0), registered_at timestamptz not null default now(), updated_at timestamptz not null default now(), notes text
);
create index if not exists idx_catreg_tournament on public.category_registrations(tournament_id);
create index if not exists idx_catreg_team on public.category_registrations(team_id);
create index if not exists idx_catreg_player on public.category_registrations(player_id);
create index if not exists idx_catreg_category on public.category_registrations(category_id);
create index if not exists idx_catreg_anyo_entry on public.category_registrations(anyo_entry_id);
create unique index if not exists uq_catreg_active_player_category on public.category_registrations(player_id,category_id) where status='ACTIVE' and player_id is not null;
create unique index if not exists uq_catreg_active_anyo_entry on public.category_registrations(anyo_entry_id) where status='ACTIVE' and anyo_entry_id is not null;

create table if not exists public.registration_changes (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 registration_id uuid not null references public.category_registrations(id) on delete cascade,
 old_category_id uuid references public.categories(id) on delete set null, new_category_id uuid references public.categories(id) on delete set null,
 old_status text, new_status text, reason text, changed_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
create index if not exists idx_regchanges_registration on public.registration_changes(registration_id);

create table if not exists public.registration_payments (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 registration_id uuid not null references public.category_registrations(id) on delete cascade, team_id uuid references public.teams(id) on delete set null,
 amount numeric(12,2) not null check(amount>=0), payment_status text not null default 'PAID' check(payment_status in ('UNPAID','PARTIALLY_PAID','PAID','WAIVED')),
 payment_method text, receipt_number text, paid_at timestamptz, recorded_by uuid references public.profiles(id) on delete set null, notes text, created_at timestamptz not null default now()
);
create index if not exists idx_regpayments_tournament on public.registration_payments(tournament_id);
create index if not exists idx_regpayments_registration on public.registration_payments(registration_id);
create index if not exists idx_regpayments_team on public.registration_payments(team_id);

create table if not exists public.team_participations (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 team_id uuid not null references public.teams(id) on delete cascade, status text not null default 'EXPECTED' check(status in ('EXPECTED','PRESENT','NO_SHOW')),
 marked_by uuid references public.profiles(id) on delete set null, marked_at timestamptz, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tournament_id,team_id)
);
create index if not exists idx_team_participations_tournament on public.team_participations(tournament_id);

alter table public.categories add column if not exists registration_fee numeric(12,2) not null default 0 check(registration_fee>=0);
alter table public.categories add column if not exists weight_requirement text;
update public.categories set weight_requirement=case when coalesce(weight_required,false) then 'required' else 'not_required' end where weight_requirement is null;
alter table public.categories drop constraint if exists categories_weight_requirement_check;
alter table public.categories add constraint categories_weight_requirement_check check(weight_requirement in ('not_required','required','optional'));

alter table public.tournaments add column if not exists registration_status text not null default 'OPEN';
alter table public.tournaments drop constraint if exists tournaments_registration_status_check;
alter table public.tournaments add constraint tournaments_registration_status_check check(registration_status in ('OPEN','FINALIZED','IN_PROGRESS','COMPLETED'));
alter table public.tournaments add column if not exists registration_finalized_at timestamptz;
alter table public.tournaments add column if not exists registration_finalized_by uuid references public.profiles(id) on delete set null;
alter table public.tournaments add column if not exists tournament_started_at timestamptz;
alter table public.tournaments add column if not exists tournament_completed_at timestamptz;

alter table public.staff_court_assignments enable row level security;
alter table public.category_registrations enable row level security;
alter table public.registration_changes enable row level security;
alter table public.registration_payments enable row level security;
alter table public.team_participations enable row level security;

drop policy if exists staff_court_member_select on public.staff_court_assignments;
create policy staff_court_member_select on public.staff_court_assignments for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists staff_court_admin_all on public.staff_court_assignments;
create policy staff_court_admin_all on public.staff_court_assignments for all to authenticated using (has_tournament_role(tournament_id,array['admin','ADMIN'])) with check (has_tournament_role(tournament_id,array['admin','ADMIN']));

drop policy if exists catreg_member_select on public.category_registrations;
create policy catreg_member_select on public.category_registrations for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists catreg_manager_write on public.category_registrations;
create policy catreg_manager_write on public.category_registrations for all to authenticated using (has_tournament_role(tournament_id,array['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER'])) with check (has_tournament_role(tournament_id,array['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));

drop policy if exists regchanges_member_select on public.registration_changes;
create policy regchanges_member_select on public.registration_changes for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists regchanges_manager_write on public.registration_changes;
create policy regchanges_manager_write on public.registration_changes for insert to authenticated with check (has_tournament_role(tournament_id,array['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));

drop policy if exists regpayments_member_select on public.registration_payments;
create policy regpayments_member_select on public.registration_payments for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists regpayments_accountant_write on public.registration_payments;
create policy regpayments_accountant_write on public.registration_payments for all to authenticated using (has_tournament_role(tournament_id,array['admin','ADMIN','accountant','ACCOUNTANT'])) with check (has_tournament_role(tournament_id,array['admin','ADMIN','accountant','ACCOUNTANT']));

drop policy if exists teampart_member_select on public.team_participations;
create policy teampart_member_select on public.team_participations for select to authenticated using (is_tournament_member(tournament_id));
drop policy if exists teampart_staff_write on public.team_participations;
create policy teampart_staff_write on public.team_participations for all to authenticated using (has_tournament_role(tournament_id,array['admin','ADMIN','accountant','ACCOUNTANT','tournament_manager','TOURNAMENT_MANAGER','table_official','TABLE_OFFICIAL'])) with check (has_tournament_role(tournament_id,array['admin','ADMIN','accountant','ACCOUNTANT','tournament_manager','TOURNAMENT_MANAGER','table_official','TABLE_OFFICIAL']));

grant select,insert,update,delete on public.staff_court_assignments,public.category_registrations,public.registration_changes,public.registration_payments,public.team_participations to authenticated;
revoke all on public.staff_court_assignments,public.category_registrations,public.registration_changes,public.registration_payments,public.team_participations from anon;


-- V27 FREE / PAID TOURNAMENT BILLING MODE
-- RADIUM V27: FREE / PAID tournament billing mode
-- Supabase is authoritative. FREE affects financial UI/registration fees only.

alter table public.tournaments add column if not exists billing_mode text not null default 'PAID';
alter table public.tournaments add column if not exists currency text not null default 'PHP';
alter table public.tournaments drop constraint if exists tournaments_billing_mode_check;
alter table public.tournaments add constraint tournaments_billing_mode_check check (billing_mode in ('PAID','FREE'));
