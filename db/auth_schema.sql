-- RADIUM separate Admin / Official accounts
-- Run this ONCE in Supabase SQL Editor.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('ADMIN','OFFICIAL')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can read own RADIUM profile" on public.profiles;
create policy "Users can read own RADIUM profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

-- After creating the two users in Supabase Authentication > Users,
-- assign their roles with the examples below (replace the emails).
--
-- insert into public.profiles (id, role)
-- select id, 'ADMIN' from auth.users where email = 'admin@example.com'
-- on conflict (id) do update set role = excluded.role;
--
-- insert into public.profiles (id, role)
-- select id, 'OFFICIAL' from auth.users where email = 'official@example.com'
-- on conflict (id) do update set role = excluded.role;
