-- RADIUM V31 additions
create table if not exists public.category_court_assignments (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 category_id uuid not null references public.categories(id) on delete cascade, court_id uuid not null references public.courts(id) on delete restrict,
 assigned_by uuid references public.profiles(id) on delete set null, active boolean not null default true,
 assigned_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tournament_id,category_id)
);
create table if not exists public.team_payments (
 id uuid primary key default gen_random_uuid(), tournament_id uuid not null references public.tournaments(id) on delete cascade,
 team_id uuid not null references public.teams(id) on delete cascade, amount numeric not null check(amount>=0), payment_method text,
 receipt_number text, paid_at timestamptz not null default now(), recorded_by uuid references public.profiles(id) on delete set null,
 notes text, created_at timestamptz not null default now()
);
alter table public.category_court_assignments enable row level security;
alter table public.team_payments enable row level security;
-- Apply these policies if the database has the standard RADIUM membership helpers.
drop policy if exists v31_category_court_read on public.category_court_assignments;
create policy v31_category_court_read on public.category_court_assignments for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists v31_category_court_write on public.category_court_assignments;
create policy v31_category_court_write on public.category_court_assignments for all to authenticated using(has_tournament_role(tournament_id,array['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER'])) with check(has_tournament_role(tournament_id,array['admin','ADMIN','tournament_manager','TOURNAMENT_MANAGER']));
drop policy if exists v31_team_payments_read on public.team_payments;
create policy v31_team_payments_read on public.team_payments for select to authenticated using(is_tournament_member(tournament_id));
drop policy if exists v31_team_payments_write on public.team_payments;
create policy v31_team_payments_write on public.team_payments for all to authenticated using(has_tournament_role(tournament_id,array['admin','ADMIN','accountant','ACCOUNTANT'])) with check(has_tournament_role(tournament_id,array['admin','ADMIN','accountant','ACCOUNTANT']));
