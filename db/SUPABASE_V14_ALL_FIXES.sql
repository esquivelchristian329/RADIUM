-- RADIUM V14 final migration / fixes
-- Run this AFTER the main db/schema.sql in Supabase SQL Editor.
-- Safe to re-run.

-- Anyo judging accepts the required 7.5–10.0 range.
alter table if exists anyo_judge_scores
drop constraint if exists anyo_judge_scores_score_check;
alter table if exists anyo_judge_scores
add constraint anyo_judge_scores_score_check check (score between 7.50 and 10.00);

-- Make sure the normalized category membership table is readable by tournament members
-- and writable by tournament admins.
drop policy if exists category_players_read on category_players;
create policy category_players_read on category_players
for select to authenticated
using (exists (select 1 from categories c where c.id=category_id and is_tournament_member(c.tournament_id)));

drop policy if exists category_players_admin on category_players;
create policy category_players_admin on category_players
for all to authenticated
using (exists (select 1 from categories c where c.id=category_id and has_tournament_role(c.tournament_id,array['admin'])))
with check (exists (select 1 from categories c where c.id=category_id and has_tournament_role(c.tournament_id,array['admin'])));

-- Normalized bracket rows belong to the tournament/category and are removed automatically
-- when their parent tournament/category is deleted. PostgreSQL CASCADE performs that
-- referential cleanup at the database level.

-- Security hardening
alter function public.radium_updated_at() set search_path = public;
alter function public.radium_jsonb_merge(jsonb,jsonb) set search_path = public;
revoke execute on function public.rls_auto_enable() from public;
revoke execute on function public.rls_auto_enable() from anon;
revoke execute on function public.rls_auto_enable() from authenticated;
