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
